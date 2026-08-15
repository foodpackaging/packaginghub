require('dotenv').config();

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

module.exports = {
  port: process.env.PORT || 4000,
  corsOrigins: (process.env.CORS_ORIGIN || 'http://localhost:5173').split(',').map((s) => s.trim()),
  mongoUri: () => required('MONGODB_URI'),
  jwt: {
    accessSecret: () => required('JWT_ACCESS_SECRET'),
    refreshSecret: () => required('JWT_REFRESH_SECRET'),
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '1h',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
  },
  razorpay: {
    keyId: process.env.RAZORPAY_KEY_ID,
    keySecret: process.env.RAZORPAY_KEY_SECRET,
  },
  firebase: {
    /**
     * Service-account credentials for Firebase Admin, or null when unset.
     *
     * Two shapes are accepted so the same code works locally and on hosts that
     * only allow single-line env vars:
     *   FIREBASE_SERVICE_ACCOUNT       — the whole service-account JSON, raw or base64
     *   FIREBASE_PROJECT_ID / _CLIENT_EMAIL / _PRIVATE_KEY — the three fields separately
     */
    credentials: () => {
      const blob = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (blob && blob.trim()) {
        const raw = blob.trim().startsWith('{')
          ? blob
          : Buffer.from(blob, 'base64').toString('utf8');
        try {
          const parsed = JSON.parse(raw);
          return {
            projectId: parsed.project_id,
            clientEmail: parsed.client_email,
            privateKey: parsed.private_key,
          };
        } catch (err) {
          console.error('[push] FIREBASE_SERVICE_ACCOUNT is not valid JSON:', err.message);
          return null;
        }
      }

      const projectId = process.env.FIREBASE_PROJECT_ID;
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      // .env files can't hold real newlines, so the key is usually stored with literal \n.
      const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
      if (!projectId || !clientEmail || !privateKey) return null;
      return { projectId, clientEmail, privateKey };
    },
  },
  // Used to render delivery times ("Arriving by 6:30 PM") in the customer's local time.
  timezone: process.env.APP_TIMEZONE || 'Asia/Kolkata',
  currency: process.env.APP_CURRENCY || 'INR',
  smtp: {
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    from: process.env.SMTP_FROM || 'B2B Store <no-reply@example.com>',
  },
};
