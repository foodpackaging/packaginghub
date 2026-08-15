/**
 * Sends a test push to a user, to check Firebase credentials and device
 * registration without having to walk an order through its whole lifecycle.
 *
 *   node scripts/testPush.js customer@example.com
 */
const { connectDb } = require('../src/config/db');
const User = require('../src/models/User');
const DeviceToken = require('../src/models/DeviceToken');
const { notifyUser } = require('../src/services/pushService');
const { getFirebaseApp } = require('../src/config/firebase');

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node scripts/testPush.js <user-email>');
    process.exit(1);
  }

  await connectDb();

  if (!getFirebaseApp()) {
    console.error('Firebase is not configured — see docs/FIREBASE_PUSH_SETUP.md section 5.');
    process.exit(1);
  }

  const user = await User.findOne({ email: email.toLowerCase().trim() });
  if (!user) {
    console.error(`No user found with email ${email}`);
    process.exit(1);
  }

  const deviceCount = await DeviceToken.countDocuments({ userId: user._id });
  console.log(`User ${user.email} has ${deviceCount} registered device(s).`);
  if (deviceCount === 0) {
    console.error('Nothing to send to. Sign in on the app first so it can register a token.');
    process.exit(1);
  }

  await notifyUser(user._id, {
    type: 'general',
    title: 'Test notification 🔔',
    body: 'If you can read this, push notifications are working end to end.',
    data: { route: 'notifications' },
  });

  console.log('Sent. Check the device (and the in-app inbox).');
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
