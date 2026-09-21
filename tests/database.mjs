import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const pg=new PGlite();
try{
await pg.exec(`create role anon; create role authenticated; create schema auth;
create table auth.identities(user_id uuid,provider text,provider_id text);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon;
insert into auth.identities values('00000000-0000-0000-0000-000000000001','discord','100000000000000001'),('00000000-0000-0000-0000-000000000002','discord','100000000000000002'),('00000000-0000-0000-0000-000000000003','discord','100000000000000003');`);
await pg.exec(await readFile(new URL('../supabase/schema.sql',import.meta.url),'utf8'));
await pg.exec(`insert into public.members values('100000000000000001','Owner','owner',true),('100000000000000002','Employee','employee',true)`);
async function as(n){await pg.exec(`reset role;set request.jwt.claim.sub='00000000-0000-0000-0000-00000000000${n}';set role authenticated;`)}
async function reject(sql){await assert.rejects(()=>pg.exec(sql))}
await as(3);assert.equal((await pg.query('select * from public.members')).rows.length,0);await reject('select public.punch()');
await as(2);await reject(`update public.members set role='owner' where discord_id='100000000000000002'`);await reject(`select public.save_member('100000000000000002','Employee','owner',true)`);await reject(`select public.record_entry('bad',100,'Altro')`);
await pg.exec('select public.punch()');assert.equal((await pg.query('select * from public.shifts where ended_at is null')).rows.length,1);await pg.exec('select public.punch()');assert.equal((await pg.query('select * from public.shifts where ended_at is null')).rows.length,0);
await reject(`select public.record_sale('Client','Car','',-5,1,0)`);
await reject(`select public.record_sale('Client','Car','',100,1,101)`);
const result=await pg.query(`select public.record_sale('Client','Car','SM01',1000,600,50) as id`);const id=result.rows[0].id;
assert.equal((await pg.query('select * from public.sales')).rows.length,1);assert.equal((await pg.query('select * from public.entries')).rows.length,0);await reject(`select public.void_sale('${id}')`);
await as(1);assert.equal(Number((await pg.query('select sum(amount) as sum from public.entries')).rows[0].sum),1000);
await pg.exec(`select public.record_sale('Client 2','Car 2','SM02',2000,1000,50)`);
await as(2);assert.equal((await pg.query('select * from public.sales')).rows.length,1);
await as(1);await pg.exec(`select public.void_sale('${id}')`);await reject(`select public.void_sale('${id}')`);assert.equal(Number((await pg.query('select sum(amount) as sum from public.entries')).rows[0].sum),2000);
await reject(`select public.save_member('100000000000000001','Owner','employee',true)`);
await as(2);await pg.exec('select public.punch()');
await as(1);await pg.exec(`select public.save_member('100000000000000002','Employee','employee',false)`);
assert.equal((await pg.query('select * from public.shifts where ended_at is null')).rows.length,0);
await as(2);await reject('select public.punch()');assert.equal((await pg.query('select * from public.sales')).rows.length,0);
await pg.exec('reset role;set role anon;');await reject('select * from public.members');await reject('select public.my_discord()');
console.log('PASS: schema, identity, RLS, unauthorized access, role escalation, shifts, sales atomicity, reversal, revocation and audit access.');
}finally{await pg.close()}
