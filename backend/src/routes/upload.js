const express = require('express');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

const ALLOWED_FOLDERS = new Set(['products', 'categories', 'banners', 'general']);

function uploadBuffer(buffer, folder) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream({ folder: `b2b-store/${folder}` }, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
    stream.end(buffer);
  });
}

router.post('/', requireAuth, requireAdmin, upload.single('file'), async (req, res) => {
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
