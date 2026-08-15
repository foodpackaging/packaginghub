const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Address = require('../models/Address');
const { serializeUser, serializeAddress } = require('../utils/serializers');
const { promoteToDefault, validateAddress, fieldsFromBody } = require('./addresses');

const router = express.Router();

// Maps incoming snake_case body keys to the User model's field names.
// `role` here is the business role text (e.g. "Owner"), not the auth role.
const EDITABLE_FIELD_MAP = {
  first_name: 'firstName',
  last_name: 'lastName',
  phone: 'phone',
  work_email: 'workEmail',
  company_type: 'companyType',
  role: 'businessRole',
  role_description: 'roleDescription',
  gst_number: 'gstNumber',
  address: 'address',
  latitude: 'latitude',
  longitude: 'longitude',
  location_url: 'locationUrl',
  avatar_url: 'avatarUrl',
};

function applyEditableFields(user, body) {
  for (const [incomingKey, modelField] of Object.entries(EDITABLE_FIELD_MAP)) {
    if (!(incomingKey in body)) continue;
    // User.address is the legacy flattened string kept in sync with the default
    // Address document. Structured address objects belong to /addresses, and
    // assigning one here would throw a Mongoose cast error.
    if (incomingKey === 'address' && body.address !== null && typeof body.address === 'object') continue;
    user[modelField] = body[incomingKey];
  }
}

router.get('/', requireAuth, (req, res) => {
  res.json({ profile: serializeUser(req.user) });
});

router.patch('/', requireAuth, async (req, res) => {
  applyEditableFields(req.user, req.body);
  await req.user.save();
  res.json({ profile: serializeUser(req.user) });
});

/**
 * Finishes onboarding. Accepts an optional structured `address` object, which is
 * saved as the business's first (default) delivery address.
 *
 * Onboarding is only marked complete once that address exists, so a returning
 * user is never bounced back into address setup — and never lands in the app
 * with no address to check out against.
 */
router.post('/complete-onboarding', requireAuth, async (req, res) => {
  const { address } = req.body;

  let created = null;
  if (address && typeof address === 'object') {
    const error = validateAddress(address);
    if (error) return res.status(400).json({ error });

    created = await Address.create({
      userId: req.user._id,
      ...fieldsFromBody(address),
      label: (address.label || '').trim() || 'Primary Address',
      isDefault: true,
    });
  } else {
    // Refuse to mark onboarding complete without a delivery address on file:
    // that state sends the user into the app only to dead-end at checkout.
    const existing = await Address.countDocuments({ userId: req.user._id });
    if (existing === 0) {
      return res.status(400).json({ error: 'A primary delivery address is required to finish setup' });
    }
  }

  // `address` here is the structured object handled above. User.address is a
  // legacy string field, so passing the object through would fail the cast —
  // promoteToDefault writes the flattened string version instead.
  const { address: _structuredAddress, ...editableBody } = req.body;
  applyEditableFields(req.user, editableBody);
  req.user.onboardingComplete = true;
  await req.user.save();

  // Runs after save so the legacy address mirror isn't clobbered by applyEditableFields.
  if (created) await promoteToDefault(req.user, created);

  res.json({
    profile: serializeUser(req.user),
    ...(created ? { address: serializeAddress(created) } : {}),
  });
});

module.exports = router;
