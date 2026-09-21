import type { Shift } from './types.ts';
export function hours(shifts:Shift[],from:number,to:number,now=Date.now()){
 return shifts.reduce((sum,s)=>sum+Math.max(0,Math.min(to,s.ended_at?Date.parse(s.ended_at):now)-Math.max(from,Date.parse(s.started_at)))/3600000,0);
}
export function heatmap(shifts:Shift[],from:number,to:number,now=Date.now()){
 const cells=Array.from({length:7},()=>Array(24).fill(0) as number[]);
 const format=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',weekday:'short',hour:'2-digit',hourCycle:'h23'});
 const weekdays=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
 for(const s of shifts){let t=Math.max(from,Date.parse(s.started_at));const end=Math.min(to,s.ended_at?Date.parse(s.ended_at):now);
 while(t<end){const next=Math.min(end,(Math.floor(t/3600000)+1)*3600000);const p=format.formatToParts(new Date(t));const day=weekdays.indexOf(p.find(x=>x.type==='weekday')!.value);const hour=Number(p.find(x=>x.type==='hour')!.value);cells[day][hour]+=(next-t)/3600000;t=next;}}
 return cells;
}
export function money(n:number){return new Intl.NumberFormat('it-IT',{style:'currency',currency:'USD',currencyDisplay:'narrowSymbol',maximumFractionDigits:0}).format(n);}
export function csv(rows:(string|number)[][]){return '\ufeff'+rows.map(row=>row.map(v=>'"'+String(v).replace(/^[=+@\-\t\r]/,"'$&").replaceAll('"','""')+'"').join(';')).join('\r\n');}
