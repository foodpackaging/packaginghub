const { startDb, stopDb, clearDb, createUser } = require('./testHelpers');
const request = require('supertest');
const app = require('../../server');

beforeAll(startDb);
afterAll(stopDb);
afterEach(clearDb);

describe('POST /api/auth/login (Priority 5)', () => {
  test('succeeds with correct credentials', async () => {
    const email = 'login-success@test.com';
    const password = 'correct-password';
    await createUser({ email, password });

    const res = await request(app).post('/api/auth/login').send({ email, password }).expect(200);

    expect(res.body.access_token).toBeTruthy();
    expect(res.body.user.email).toBe(email);
  });

  test('returns a generic 401 for incorrect credentials, without revealing which check failed', async () => {
    const email = 'login-fail@test.com';
    await createUser({ email, password: 'the-real-password' });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'wrong-password' })
      .expect(401);

    expect(res.body.error).toBe('Invalid email or password');
  });

  test('rate-limits repeated attempts from the same client', async () => {
    const email = 'rate-limit-test@test.com';
    await createUser({ email, password: 'the-real-password' });

    let lastStatus;
    // loginLimiter allows 10 requests per window (middleware/rateLimit.js) — the 11th should 429.
    for (let i = 0; i < 11; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      const res = await request(app).post('/api/auth/login').send({ email, password: 'wrong-password' });
      lastStatus = res.status;
    }

    expect(lastStatus).toBe(429);
  });
});

describe('Admin-only route protection (Priority 6/8 area)', () => {
  test('a non-admin token is rejected from an admin-only route', async () => {
    const { token } = await createUser({ role: 'customer' });

    await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Should not be created', price: 10 })
      .expect(403);
  });

  test('an admin token is accepted on the same route', async () => {
    const { token } = await createUser({ role: 'admin' });

    await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Created by admin', price: 10 })
      .expect(201);
  });

  test('an unauthenticated request to the same route is rejected', async () => {
    await request(app).post('/api/products').send({ name: 'No auth', price: 10 }).expect(401);
  });
});

describe('GET /api/products?all=true (Priority 6)', () => {
  test('is rejected for an unauthenticated caller', async () => {
    await request(app).get('/api/products?all=true').expect(401);
  });

  test('is rejected for a non-admin caller', async () => {
    const { token } = await createUser({ role: 'customer' });
    await request(app).get('/api/products?all=true').set('Authorization', `Bearer ${token}`).expect(403);
  });

  test('is allowed for an admin caller', async () => {
    const { token } = await createUser({ role: 'admin' });
    await request(app).get('/api/products?all=true').set('Authorization', `Bearer ${token}`).expect(200);
  });

  test('the plain (non-all) listing stays public', async () => {
    await request(app).get('/api/products').expect(200);
  });
});
