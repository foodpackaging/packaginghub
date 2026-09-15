const express = require('express');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif']);

function fileFilter(req, file, cb) {
  const ext = (file.originalname.match(/\.[^.]+$/)?.[0] || '').toLowerCase();
  if (!ALLOWED_MIME_TYPES.has(file.mimetype) || !ALLOWED_EXTENSIONS.has(ext)) {
    return cb(new Error('Only JPEG, PNG, WebP, or GIF images are allowed'));
  }
  cb(null, true);
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter,
});

const ALLOWED_FOLDERS = new Set(['products', 'categories', 'banners', 'general']);

// multer reports a rejected file/oversize file through the callback style,
// not a thrown error an async handler could catch — without this it would
// fall through to the generic 500 handler instead of a specific 400.
function uploadSingle(req, res, next) {
  upload.single('file')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}

function uploadBuffer(buffer, folder) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream({ folder: `b2b-store/${folder}` }, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
    stream.end(buffer);
  });
}

router.post('/', requireAuth, requireAdmin, uploadSingle, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

  const folder = ALLOWED_FOLDERS.has(req.body.folder) ? req.body.folder : 'general';

  try {
    const result = await uploadBuffer(req.file.buffer, folder);
    res.json({ url: result.secure_url, public_id: result.public_id });
  } catch (err) {
    res.status(502).json({ error: 'Image upload failed', details: err.message });
  }
});

function publicIdFromUrl(url) {
  // e.g. https://res.cloudinary.com/<cloud>/image/upload/v169.../b2b-store/products/abc123.jpg
  const match = url.match(/\/upload\/(?:v\d+\/)?(.+)\.[a-zA-Z0-9]+$/);
  return match ? match[1] : null;
}

router.delete('/', requireAuth, requireAdmin, async (req, res) => {
  const publicId = req.body.public_id || (req.body.url && publicIdFromUrl(req.body.url));
  if (!publicId) return res.status(400).json({ error: 'public_id or a Cloudinary url is required' });

  try {
    await cloudinary.uploader.destroy(publicId);
    res.json({ ok: true });
  } catch (err) {
    res.status(502).json({ error: 'Image deletion failed', details: err.message });
  }
});

module.exports = router;
