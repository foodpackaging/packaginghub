const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const env = require('./config/env');
const { connectDb } = require('./config/db');

const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const { router: addressRoutes } = require('./routes/addresses');
const categoryRoutes = require('./routes/categories');
const productRoutes = require('./routes/products');
const filterRoutes = require('./routes/filters');
const bannerRoutes = require('./routes/banners');
const couponRoutes = require('./routes/coupons');
const orderRoutes = require('./routes/orders');
const returnRoutes = require('./routes/returns');
const customerRoutes = require('./routes/customers');
const uploadRoutes = require('./routes/upload');
const paymentRoutes = require('./routes/payments');
const deviceRoutes = require('./routes/devices');
const notificationRoutes = require('./routes/notifications');

const app = express();

app.use(cors({ origin: env.corsOrigins, credentials: true }));
app.use(cookieParser());
app.use(express.json());

app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/addresses', addressRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/products', productRoutes);
app.use('/api/filters', filterRoutes);
app.use('/api/banners', bannerRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/returns', returnRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/notifications', notificationRoutes);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

// Only bind a port when this file is run directly (`npm start`, `npm run dev`).
// Under Vercel the module is imported by api/index.js and invoked per request —
// there is no long-running process, and calling listen() there would either be
// ignored or hold the function open.
if (require.main === module) {
  connectDb()
    .then(() => app.listen(env.port, () => console.log(`API listening on port ${env.port}`)))
    .catch((err) => {
      console.error('Failed to start server:', err);
      process.exit(1);
    });
}

module.exports = app;
