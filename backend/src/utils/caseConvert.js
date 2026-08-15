function toCamel(str) {
  return str.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
}

// Converts only top-level keys; nested object/array values are left untouched
// (Mixed fields like `attributes` or `delivery_address` are meant to be stored opaque).
function shallowCamelize(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    result[toCamel(key)] = value;
  }
  return result;
}

function camelizeArray(arr) {
  return Array.isArray(arr) ? arr.map(shallowCamelize) : arr;
}

module.exports = { toCamel, shallowCamelize, camelizeArray };
