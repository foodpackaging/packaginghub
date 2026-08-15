// Backfills the Address collection from the legacy single User.address string.
//
//   npm run migrate-addresses            # dry run, prints what it would do
//   npm run migrate-addresses -- --apply # actually writes
//
// Safe to re-run: users who already have an Address document are skipped.

require('dotenv').config();
const mongoose = require('mongoose');
const env = require('../src/config/env');
const User = require('../src/models/User');
const Address = require('../src/models/Address');

const APPLY = process.argv.includes('--apply');

/**
 * The old onboarding screen stored "street, city, state - pincode", so that exact
 * shape can be recovered. Anything else keeps the whole string in line1 rather
 * than guessing wrongly — a wrong city is worse than a blank one the user fills in.
 */
function parseLegacyAddress(raw) {
  const text = (raw || '').trim();
  if (!text) return null;

  const withPin = text.match(/^(.*?),\s*([^,]+),\s*([^,]+?)\s*-\s*(\d{6})\s*$/);
  if (withPin) {
    return {
      line1: withPin[1].trim(),
      city: withPin[2].trim(),
      state: withPin[3].trim(),
      pincode: withPin[4].trim(),
      parsed: 'full',
    };
  }

  // Recover a trailing 6-digit pincode even when the rest doesn't match.
  const looseP = text.match(/(\d{6})\s*$/);
  return {
    line1: text.replace(/\s*[-,]?\s*\d{6}\s*$/, '').trim() || text,
    city: '',
    state: '',
    pincode: looseP ? looseP[1] : '',
    parsed: looseP ? 'pincode-only' : 'none',
  };
}

async function main() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri());

  const users = await User.find({ address: { $nin: [null, ''] } });
  console.log(`${users.length} user(s) have a legacy address string.\n`);

  const summary = { created: 0, skipped: 0, needsReview: 0 };

  for (const user of users) {
    const already = await Address.countDocuments({ userId: user._id });
    if (already > 0) {
      summary.skipped += 1;
      console.log(`SKIP    ${user.email} — already has ${already} address(es)`);
      continue;
    }

    const parsed = parseLegacyAddress(user.address);
    if (!parsed) {
      summary.skipped += 1;
      continue;
    }

    // city/state/pincode are required by the schema. Placeholders keep the record
    // creatable and are flagged below so the business can correct them in-app.
    const incomplete = !parsed.city || !parsed.state || !parsed.pincode;
    const doc = {
      userId: user._id,
      label: 'Primary Address',
      line1: parsed.line1,
      city: parsed.city || 'Unknown',
      state: parsed.state || 'Unknown',
      pincode: parsed.pincode || '000000',
      country: 'India',
      contactName: [user.firstName, user.lastName].filter(Boolean).join(' ').trim(),
      contactPhone: user.phone || '',
      latitude: user.latitude,
      longitude: user.longitude,
      isDefault: true,
    };

    if (incomplete) summary.needsReview += 1;
    summary.created += 1;

    console.log(
      `${APPLY ? 'CREATE ' : 'WOULD  '} ${user.email} [${parsed.parsed}]` +
        `${incomplete ? '  <-- NEEDS REVIEW (missing city/state/pincode)' : ''}`
    );
    console.log(`         "${user.address}"`);
    console.log(`         -> line1="${doc.line1}" city="${doc.city}" state="${doc.state}" pin="${doc.pincode}"`);

    if (APPLY) await Address.create(doc);
  }

  console.log(
    `\n${APPLY ? 'Applied' : 'Dry run'}: ${summary.created} to create, ${summary.skipped} skipped, ` +
      `${summary.needsReview} need manual review.`
  );
  if (!APPLY && summary.created > 0) console.log('Re-run with --apply to write these.');
  if (summary.needsReview > 0) {
    console.log(
      'Addresses marked NEEDS REVIEW have placeholder city/state/pincode; the pincode\n' +
        'placeholder 000000 fails the API validator, so those users will be asked to\n' +
        'correct the address the first time they edit it.'
    );
  }

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
