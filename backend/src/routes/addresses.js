const express = require('express');
const Address = require('../models/Address');
const { requireAuth } = require('../middleware/auth');
const { serializeAddress, formatAddressLine } = require('../utils/serializers');

const router = express.Router();

const REQUIRED_FIELDS = ['line1', 'city', 'state', 'pincode'];
const PINCODE_PATTERN = /^[1-9][0-9]{5}$/; // Indian PIN: 6 digits, never leading zero.

/**
 * Validates the client payload. Returns an error string, or null when valid.
 * Mirrors the Flutter form's rules so a bypassed client can't store junk.
 */
function validateAddress(body) {
  for (const field of REQUIRED_FIELDS) {
    if (!body[field] || !String(body[field]).trim()) {
      return `${field.replace('line1', 'address')} is required`;
    }
  }
  if (!PINCODE_PATTERN.test(String(body.pincode).trim())) {
    return 'Enter a valid 6-digit pincode';
  }
  return null;
}

function fieldsFromBody(body) {
  const pick = (key, fallback = '') =>
    body[key] === undefined || body[key] === null ? fallback : String(body[key]).trim();

  return {
    label: pick('label'),
    contactName: pick('contact_name'),
    contactPhone: pick('contact_phone'),
    line1: pick('line1'),
    area: pick('area'),
    city: pick('city'),
    state: pick('state'),
    pincode: pick('pincode'),
    country: pick('country', 'India') || 'India',
    landmark: pick('landmark'),
    // Coordinates are optional GPS assistance, never required.
    latitude: body.latitude === undefined || body.latitude === null ? undefined : Number(body.latitude),
    longitude: body.longitude === undefined || body.longitude === null ? undefined : Number(body.longitude),
  };
}

/**
 * Enforces exactly one default per user by clearing the flag everywhere else.
 * Also mirrors the default onto the legacy User.address/latitude/longitude fields
 * so existing admin views and older clients keep showing something sensible.
 */
async function promoteToDefault(user, address) {
  await Address.updateMany({ userId: user._id, _id: { $ne: address._id } }, { $set: { isDefault: false } });
  if (!address.isDefault) {
    address.isDefault = true;
    await address.save();
  }

  user.address = formatAddressLine(address);
  if (address.latitude != null) user.latitude = address.latitude;
  if (address.longitude != null) user.longitude = address.longitude;
  if (address.latitude != null && address.longitude != null) {
    user.locationUrl = `https://www.google.com/maps?q=${address.latitude},${address.longitude}`;
  }
  await user.save();
}

/** Re-syncs the legacy mirror after the default may have changed. */
async function syncLegacyMirror(user) {
  const current = await Address.findOne({ userId: user._id, isDefault: true });
  user.address = current ? formatAddressLine(current) : '';
  if (!current) {
    user.latitude = undefined;
    user.longitude = undefined;
    user.locationUrl = '';
  }
  await user.save();
}

router.get('/', requireAuth, async (req, res) => {
  const addresses = await Address.find({ userId: req.user._id }).sort({ isDefault: -1, updatedAt: -1 });
  res.json({ addresses: addresses.map(serializeAddress) });
});

router.post('/', requireAuth, async (req, res) => {
  const error = validateAddress(req.body);
  if (error) return res.status(400).json({ error });

  const existingCount = await Address.countDocuments({ userId: req.user._id });
  const address = await Address.create({
    userId: req.user._id,
    ...fieldsFromBody(req.body),
    // The very first address is always the default — a business should never be
    // left with saved addresses but nothing selected at checkout.
    isDefault: existingCount === 0 ? true : req.body.is_default === true,
  });

  if (address.isDefault) await promoteToDefault(req.user, address);

  res.status(201).json({ address: serializeAddress(address) });
});

router.patch('/:id', requireAuth, async (req, res) => {
  const address = await Address.findOne({ _id: req.params.id, userId: req.user._id });
  if (!address) return res.status(404).json({ error: 'Address not found' });

  const merged = { ...serializeAddress(address), ...req.body };
  const error = validateAddress(merged);
  if (error) return res.status(400).json({ error });

  Object.assign(address, fieldsFromBody(merged));
  await address.save();

  if (req.body.is_default === true) {
    await promoteToDefault(req.user, address);
  } else if (address.isDefault) {
    // Editing the default changes what the legacy mirror should say.
    await syncLegacyMirror(req.user);
  }

  res.json({ address: serializeAddress(address) });
});

router.post('/:id/default', requireAuth, async (req, res) => {
  const address = await Address.findOne({ _id: req.params.id, userId: req.user._id });
  if (!address) return res.status(404).json({ error: 'Address not found' });

  await promoteToDefault(req.user, address);
  const addresses = await Address.find({ userId: req.user._id }).sort({ isDefault: -1, updatedAt: -1 });
  res.json({ addresses: addresses.map(serializeAddress) });
});

router.delete('/:id', requireAuth, async (req, res) => {
  const address = await Address.findOne({ _id: req.params.id, userId: req.user._id });
  if (!address) return res.status(404).json({ error: 'Address not found' });

  const wasDefault = address.isDefault;
  await address.deleteOne();

  // Never leave the business without a default while other addresses remain.
  if (wasDefault) {
    const next = await Address.findOne({ userId: req.user._id }).sort({ updatedAt: -1 });
    if (next) {
      await promoteToDefault(req.user, next);
    } else {
      await syncLegacyMirror(req.user);
    }
  }

  const addresses = await Address.find({ userId: req.user._id }).sort({ isDefault: -1, updatedAt: -1 });
  res.json({ ok: true, addresses: addresses.map(serializeAddress) });
});

module.exports = { router, promoteToDefault, validateAddress, fieldsFromBody };
