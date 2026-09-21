import test from 'node:test';
import assert from 'node:assert/strict';
import { hours,heatmap,csv } from '../src/analytics.ts';
const shift=(start:string,end:string|null)=>({id:'s',discord_id:'1',started_at:start,ended_at:end});
test('Hours clip shifts spanning the selected range and open shifts',()=>{
 const a=Date.parse('2026-09-21T12:00:00Z'),b=Date.parse('2026-09-21T16:00:00Z');
 assert.equal(hours([shift('2026-09-21T10:00:00Z','2026-09-21T13:00:00Z'),shift('2026-09-21T15:00:00Z',null)],a,b,b),2);
});
test('Heatmap splits midnight in Rome and preserves fractional hours',()=>{
 const a=Date.parse('2026-09-21T21:30:00Z'),b=a+3600000;
 const h=heatmap([shift(new Date(a).toISOString(),new Date(b).toISOString())],a,b);
 assert.equal(h[0][23],.5);assert.equal(h[1][0],.5);assert.equal(h.flat().reduce((n,v)=>n+v,0),1);
});
test('Heatmap accounts for repeated hour at daylight saving transition',()=>{
 const a=Date.parse('2026-10-25T00:00:00Z'),b=Date.parse('2026-10-25T02:00:00Z');
 const h=heatmap([shift(new Date(a).toISOString(),new Date(b).toISOString())],a,b);
 assert.equal(h[6][2],2);
});
test('CSV escapes quotes and neutralizes spreadsheet formulas',()=>{
 const result=csv([['=HYPERLINK("bad")','Mario; Rossi',12]]);
 assert.ok(result.includes('"\'=HYPERLINK(""bad"")"'));assert.ok(result.includes('"Mario; Rossi"'));
});
