const crypto = require('crypto');
const { startDb, stopDb, clearDb, createUser } = require('./testHelpers');
const request = require('supertest');
const app = require('../../server');
const Order = require('../../models/Order');

beforeAll(startDb);
afterAll(stopDb);
afterEach(clearDb);

const KEY_SECRET = 'test-razorpay-key-secret'; // matches testHelpers' process.env override
const WEBHOOK_SECRET = 'test-razorpay-webhook-secret';

function createPendingOrder(userId, overrides = {}) {
  return Order.create({
    orderNumber: `ORD-TEST-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    userId,
    deliveryMethod: 'pickup',
    paymentMethod: 'online',
    paymentStatus: 'pending',
    subtotal: 100,
    totalAmount: 100,
    ...overrides,
  });
}

describe('POST /api/payments/razorpay/verify (Priority 4)', () => {
  test('accepts a correctly signed payment and marks the order paid', async () => {
    const { user, token } = await createUser();
    const order = await createPendingOrder(user._id, { razorpayOrderId: 'order_valid1' });

    const signature = crypto
      .createHmac('sha256', KEY_SECRET)
      .update('order_valid1|pay_valid1')
      .digest('hex');

    const res = await request(app)
      .post('/api/payments/razorpay/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ app_order_id: order._id.toString(), order_id: 'order_valid1', payment_id: 'pay_valid1', signature })
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.order.payment_status).toBe('paid');
  });

  test('rejects a tampered signature and leaves the order unpaid', async () => {
    const { user, token } = await createUser();
    const order = await createPendingOrder(user._id, { razorpayOrderId: 'order_valid2' });

    await request(app)
      .post('/api/payments/razorpay/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({
        app_order_id: order._id.toString(),
        order_id: 'order_valid2',
        payment_id: 'pay_valid2',
        signature: 'not-a-real-signature',
      })
      .expect(400);

    const unchanged = await Order.findById(order._id);
    expect(unchanged.paymentStatus).toBe('pending');
  });

  test('rejects a valid signature for a razorpayOrderId that does not belong to this order (replay across orders)', async () => {
    const { user, token } = await createUser();
    // This order's own Razorpay order id is 'order_mine' — the request below
    // presents a signature for a DIFFERENT Razorpay order id ('order_other'),
    // which is exactly what a customer replaying a signature from one of
    // their other paid orders would look like.
    const order = await createPendingOrder(user._id, { razorpayOrderId: 'order_mine' });

    const signature = crypto.createHmac('sha256', KEY_SECRET).update('order_other|pay_x').digest('hex');

    await request(app)
      .post('/api/payments/razorpay/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ app_order_id: order._id.toString(), order_id: 'order_other', payment_id: 'pay_x', signature })
      .expect(404);

    const unchanged = await Order.findById(order._id);
    expect(unchanged.paymentStatus).toBe('pending');
  });
});

describe('POST /api/payments/razorpay/webhook (Priority 4)', () => {
  function sign(payload) {
    return crypto.createHmac('sha256', WEBHOOK_SECRET).update(JSON.stringify(payload)).digest('hex');
  }

  test('a validly signed payment.captured event marks the matching order paid', async () => {
    const { user } = await createUser();
    await createPendingOrder(user._id, { razorpayOrderId: 'order_webhook1' });

    const payload = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_webhook1', order_id: 'order_webhook1' } } },
    };

    await request(app)
      .post('/api/payments/razorpay/webhook')
      .set('x-razorpay-signature', sign(payload))
      .send(payload)
      .expect(200);

    const order = await Order.findOne({ razorpayOrderId: 'order_webhook1' });
    expect(order.paymentStatus).toBe('paid');
    expect(order.razorpayPaymentId).toBe('pay_webhook1');
  });

  test('a redelivered (duplicate) webhook for an already-paid order is a harmless no-op', async () => {
    const { user } = await createUser();
    await createPendingOrder(user._id, { razorpayOrderId: 'order_webhook2' });

    const payload = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_webhook2', order_id: 'order_webhook2' } } },
    };
    const signature = sign(payload);

    await request(app).post('/api/payments/razorpay/webhook').set('x-razorpay-signature', signature).send(payload).expect(200);
    // Redelivered — same event, same signature, sent again.
    await request(app).post('/api/payments/razorpay/webhook').set('x-razorpay-signature', signature).send(payload).expect(200);

    const order = await Order.findOne({ razorpayOrderId: 'order_webhook2' });
    expect(order.paymentStatus).toBe('paid'); // still just paid, not double-processed into an error state
  });

  test('rejects a webhook with an invalid signature', async () => {
    const payload = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_x', order_id: 'order_x' } } },
    };

    await request(app)
      .post('/api/payments/razorpay/webhook')
      .set('x-razorpay-signature', 'totally-wrong-signature')
      .send(payload)
      .expect(400);
  });

  test('a payment.failed event marks a not-yet-paid order failed', async () => {
    const { user } = await createUser();
    await createPendingOrder(user._id, { razorpayOrderId: 'order_webhook3' });

    const payload = {
      event: 'payment.failed',
      payload: { payment: { entity: { id: 'pay_webhook3', order_id: 'order_webhook3', error_description: 'Card declined' } } },
    };

    await request(app)
      .post('/api/payments/razorpay/webhook')
      .set('x-razorpay-signature', sign(payload))
      .send(payload)
      .expect(200);

    const order = await Order.findOne({ razorpayOrderId: 'order_webhook3' });
    expect(order.paymentStatus).toBe('failed');
  });
});
