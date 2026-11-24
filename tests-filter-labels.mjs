import assert from 'node:assert/strict';
import {DEFAULT_FILTER_LABELS,normalizeTemplateHeaders} from './filter-labels.mjs';
import {prepareHistoryRows} from './historical-import.mjs';

assert.equal(DEFAULT_FILTER_LABELS.af_tag3,'Taken By');
const labels={...DEFAULT_FILTER_LABELS,af_imported_status:'Delivery Stage',af_tag:'Customer Segment',af_tag3:'Sales Owner'};
const example=[['Order ID','Customer Name','Phone','Delivery Stage','Customer Segment','Sales Owner'],['order-1','Example','01712345678','Delivered','Website','Person A']];
const normalized=normalizeTemplateHeaders(example,labels);
assert.equal(normalized[0][3],'Status');
assert.equal(normalized[0][4],'Custom Tags');
assert.equal(normalized[0][5],'Custom Tag 3');
const parsed=prepareHistoryRows(example,{filterLabels:labels});
assert.equal(parsed.length,1);
assert.equal(parsed[0].status,'Delivered');
assert.deepEqual(parsed[0].original_columns.slice(3).map(x=>[x.column,x.value]),[['Status','Delivered'],['Custom Tags','Website'],['Custom Tag 3','Person A']]);
console.log('Filter title, renamed CSV header, and Custom Tag 3 value tests passed.');
