const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const file = path.join(__dirname, 'apps/server/src/sync-and-mobile.spec.ts');
let content = fs.readFileSync(file, 'utf8');

const replacements = {
  // Shops & Devices & Pairs
  'pair-uuid-123456': '11111111-1111-1111-1111-111111111111',
  'DESKTOP-HWID-ABC': '22222222-2222-2222-2222-222222222222',
  'SMARTPHONE-DEVICE-001': '33333333-3333-3333-3333-333333333333',
  'SMARTPHONE-DEVICE-002': '44444444-4444-4444-4444-444444444444',
  'pair-pin-login': '55555555-5555-5555-5555-555555555555',
  'DEVICE-LOGIN-TEST': '66666666-6666-6666-6666-666666666666',
  
  // Events & Entities
  'evt-sale-001': '77777777-7777-7777-7777-777777777777',
  'sale-001': '88888888-8888-8888-8888-888888888888',
  'cust-amadou': '99999999-9999-9999-9999-999999999999',
  'prod-riz-50kg': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'evt-exp-001': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'exp-001': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  
  // Multi-tenant
  'HWID-A': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'evt-sale-a': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'sale-a': 'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'HWID-B': '12345678-1234-1234-1234-123456789012',
  'evt-sale-b': '12345678-1234-1234-1234-123456789013',
  'sale-b': '12345678-1234-1234-1234-123456789014',
  
  // Cancel
  'evt-sale-to-cancel': '12345678-1234-1234-1234-123456789015',
  'sale-999': '12345678-1234-1234-1234-123456789016',
  'cust-moussa': '12345678-1234-1234-1234-123456789017',
  'prod-huile': '12345678-1234-1234-1234-123456789018',
  'evt-cancel-999': '12345678-1234-1234-1234-123456789019',
  'evt-cancel-999-retry': '12345678-1234-1234-1234-123456789020',
  
  // Security
  'pair-lockout-test': '12345678-1234-1234-1234-123456789021',
  'DEVICE-LOCKOUT-001': '12345678-1234-1234-1234-123456789022',
  'pair-refresh-test': '12345678-1234-1234-1234-123456789023',
  'DEVICE-REFRESH-001': '12345678-1234-1234-1234-123456789024',
  
  // Out of order
  'evt-ooo-cancel-01': '12345678-1234-1234-1234-123456789025',
  'sale-ooo-001': '12345678-1234-1234-1234-123456789026',
  'evt-ooo-create-01': '12345678-1234-1234-1234-123456789027',
  'prod-ooo-riz': '12345678-1234-1234-1234-123456789028',
  
  // HMAC
  'pair-hmac-test': '12345678-1234-1234-1234-123456789029',
};

for (const [key, value] of Object.entries(replacements)) {
  content = content.replace(new RegExp(key, 'g'), value);
}

fs.writeFileSync(file, content);
console.log('UUIDs updated in spec file.');
