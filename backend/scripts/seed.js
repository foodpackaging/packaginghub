require('dotenv').config();
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const env = require('../src/config/env');
const User = require('../src/models/User');
const Category = require('../src/models/Category');
const Banner = require('../src/models/Banner');

async function seedAdmin() {
  const email = process.env.ADMIN_SEED_EMAIL;
  const password = process.env.ADMIN_SEED_PASSWORD;
  if (!email || !password) {
    console.log('ADMIN_SEED_EMAIL / ADMIN_SEED_PASSWORD not set, skipping admin seed.');
    return;
  }

  const existing = await User.findOne({ email: email.toLowerCase() });
  const passwordHash = await bcrypt.hash(password, 10);
  if (existing) {
    existing.role = 'admin';
    existing.passwordHash = passwordHash;
    await existing.save();
    console.log(`Updated admin user ${email} with the new password.`);
    return;
  }

  await User.create({ email: email.toLowerCase(), passwordHash, role: 'admin', onboardingComplete: true });
  console.log(`Created admin user ${email}.`);
}

async function seedSampleData() {
  const categoryCount = await Category.countDocuments();
  if (categoryCount === 0) {
    await Category.insertMany([
      { name: 'Kitchenware', sortOrder: 1 },
      { name: 'Home Decor', sortOrder: 2 },
      { name: 'Packaging', sortOrder: 3 },
    ]);
    console.log('Seeded sample top-level categories.');
  }

  const bannerCount = await Banner.countDocuments();
  if (bannerCount === 0) {
    console.log('No banners found — add some from the admin dashboard (Cloudinary upload).');
  }
}

async function main() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri());
  await seedAdmin();
  await seedSampleData();
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
