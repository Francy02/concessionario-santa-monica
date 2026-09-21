import { createClient } from '@supabase/supabase-js';
import type { Data } from './types';
const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const db=url&&key ? createClient(url,key,{auth:{flowType:'pkce',detectSessionInUrl:true}}):null;
export async function fetchData():Promise<Data>{
 if(!db) throw new Error('Database non configurato.');
 const tables=['members','shifts','sales','entries','audit'] as const;
 const results=await Promise.all(tables.map(async t=>{
  const rows:unknown[]=[];
  for(let offset=0;offset<100000;offset+=1000){
   const {data,error}=await db!.from(t).select('*').order(t==='members'?'discord_id':'id').range(offset,offset+999);
   if(error)throw error;rows.push(...data);
   if(data.length<1000){
    const key=t==='members'?'name':t==='shifts'?'started_at':'created_at';
    return (rows as Record<string,string>[]).sort((a,b)=>t==='members'?a[key].localeCompare(b[key]):b[key].localeCompare(a[key]));
   }
  }
  throw new Error('Archivio molto grande: occorre abilitare la consultazione per periodo sul server. Nessun riepilogo parziale verrà mostrato.');
 }));
 return Object.fromEntries(tables.map((t,i)=>[t,results[i]])) as unknown as Data;
}
export async function rpc(name:string,args:Record<string,unknown>={}){
 if(!db)throw new Error('Database non configurato.');
 const {data,error}=await db.rpc(name,args); if(error)throw error;return data;
}
