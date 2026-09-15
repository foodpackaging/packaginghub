const { startDb, stopDb, clearDb, createUser, createProduct } = require('./testHelpers');
const request = require('supertest');
const app = require('../../server');
const Order = require('../../models/Order');
const Product = require('../../models/Product');

beforeAll(startDb);
afterAll(stopDb);
afterEach(clearDb);

describe('POST /api/orders — server-side pricing, stock, and MOQ (Priorities 1-3)', () => {
  test('computes totals from the database and ignores a tampered client price', async () => {
    const { token } = await createUser();
    const product = await createProduct({ price: 100, stockQuantity: 50, minOrderQty: 1 });

    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        delivery_method: 'pickup',
        payment_method: 'cod',
        items: [{ product_id: product._id.toString(), quantity: 2 }],
        // These are all deliberately ignored by the server — see routes/orders.js.
        subtotal: 1,
        discount_amount: 0,
        delivery_charge: 0,
        total_amount: 1,
      })
      .expect(201);

    expect(res.body.order.subtotal).toBe(200); // 2 * real DB price (100), not the tampered total
    expect(res.body.order.total_amount).toBe(200); // pickup: no delivery charge
    expect(res.body.order.items[0].unit_price).toBe(100);
  });

  test('adds the server delivery charge for a delivery order regardless of client input', async () => {
    const { token } = await createUser();
    const product = await createProduct({ price: 100, stockQuantity: 50 });

    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        delivery_method: 'delivery',
        payment_method: 'cod',
        delivery_address: { line1: '123 Test St', city: 'Testville', state: 'TS', pincode: '123456' },
        items: [{ product_id: product._id.toString(), quantity: 1 }],
        delivery_charge: 0, // ignored — server decides this
      })
      .expect(201);

    expect(res.body.order.subtotal).toBe(100);
    expect(res.body.order.delivery_charge).toBe(50);
    expect(res.body.order.total_amount).toBe(150);
  });

  test('rejects an order for an inactive product', async () => {
    const { token } = await createUser();
    const product = await createProduct({ isActive: false });

    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        delivery_method: 'pickup',
        payment_method: 'cod',
        items: [{ product_id: product._id.toString(), quantity: 1 }],
      })
      .expect(400);

    expect(res.body.error).toBeTruthy();
    expect(await Order.countDocuments()).toBe(0);
  });

  test('rejects a quantity below the product minimum order quantity', async () => {
    const { token } = await createUser();
    const product = await createProduct({ minOrderQty: 10, stockQuantity: 100 });

    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        delivery_method: 'pickup',
        payment_method: 'cod',
        items: [{ product_id: product._id.toString(), quantity: 5 }],
      })
      .expect(400);

    expect(res.body.error).toMatch(/minimum order quantity/i);
  });

  test('rejects an order when stock is insufficient', async () => {
    const { token } = await createUser();
    const product = await createProduct({ stockQuantity: 5, minOrderQty: 1 });

    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        delivery_method: 'pickup',
        payment_method: 'cod',
        items: [{ product_id: product._id.toString(), quantity: 10 }],
      })
      .expect(400);

    expect(res.body.error).toMatch(/stock/i);
    const unchanged = await Product.findById(product._id);
    expect(unchanged.stockQuantity).toBe(5); // untouched — the transaction rolled back
  });

  test('two concurrent requests for the last units: exactly one succeeds, stock never goes negative', async () => {
    const { token } = await createUser();
    const product = await createProduct({ stockQuantity: 5, minOrderQty: 1 });

    const placeOrder = () =>
      request(app)
        .post('/api/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          delivery_method: 'pickup',
          payment_method: 'cod',
          items: [{ product_id: product._id.toString(), quantity: 5 }],
        });

    const [first, second] = await Promise.all([placeOrder(), placeOrder()]);
    const statuses = [first.status, second.status].sort();
    expect(statuses).toEqual([201, 400]);

    const finalProduct = await Product.findById(product._id);
    expect(finalProduct.stockQuantity).toBe(0); // not negative
    expect(await Order.countDocuments()).toBe(1);
  });

  test('rejects an unauthenticated request', async () => {
    const product = await createProduct();
    await request(app)
      .post('/api/orders')
      .send({
        delivery_method: 'pickup',
        payment_method: 'cod',
        items: [{ product_id: product._id.toString(), quantity: 1 }],
      })
      .expect(401);
  });
});

describe('POST /api/orders — idempotency (Priority 15)', () => {
  test('a repeated Idempotency-Key returns the original order instead of creating a second one', async () => {
    const { token } = await createUser();
    const product = await createProduct({ stockQuantity: 50 });
    const idempotencyKey = 'test-idempotency-key-1';

    const body = {
      delivery_method: 'pickup',
      payment_method: 'cod',
      items: [{ product_id: product._id.toString(), quantity: 2 }],
    };

    const first = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send(body)
      .expect(201);

    const second = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send(body)
      .expect(200);

    expect(second.body.order.id).toBe(first.body.order.id);
    expect(await Order.countDocuments()).toBe(1);

    const finalProduct = await Product.findById(product._id);
    expect(finalProduct.stockQuantity).toBe(48); // deducted once, not twice
  });
});
