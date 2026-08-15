// Applies the index definitions in the models to the live database.
//
// Mongoose creates new indexes automatically but never drops ones you removed from
// the schema, so the obsolete { attributes: 1 } index would otherwise linger and keep
// costing writes. syncIndexes() reconciles both directions.
//
//   npm run sync-indexes
//
// Building indexes locks nothing in modern MongoDB, but on a large collection it does
// consume IO — prefer running it during a quiet period in production.

require('dotenv').config();
const mongoose = require('mongoose');
const env = require('../src/config/env');
const Product = require('../src/models/Product');

async function main() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri());

  console.log('Indexes before:');
  console.table((await Product.collection.indexes()).map((i) => ({ name: i.name, key: JSON.stringify(i.key) })));

  const dropped = await Product.syncIndexes();
  console.log(dropped.length ? `Dropped stale indexes: ${dropped.join(', ')}` : 'No stale indexes to drop.');

  console.log('Indexes after:');
  console.table((await Product.collection.indexes()).map((i) => ({ name: i.name, key: JSON.stringify(i.key) })));

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
