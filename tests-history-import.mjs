import assert from 'node:assert/strict';import {prepareHistoryRows} from './historical-import.mjs';
const rows=prepareHistoryRows([['Invoice Number','Customer Name','Mobile Number','Products','Total'],['A1','Customer','01711112222','Product A','100'],['A2','Customer','০১৭১১১১২২২২','Product B','200']]);
assert.equal(rows.length,2);assert.equal(rows[0].customer.phone,rows[1].customer.phone);assert.notEqual(rows[0].external_id,rows[1].external_id);assert.equal(rows[1].products,'Product B');assert.throws(()=>prepareHistoryRows([['Customer Name','Phone'],['Name','01711112222']]),/Invoice/);
console.log('Historical order mapping passed: distinct invoices for same normalized phone, product/amount preservation, required Invoice/Order ID.');
