export type Role = 'owner' | 'manager' | 'employee';
export type Member = {discord_id:string; name:string; role:Role; active:boolean; commission_pct:number};
export type Shift = {id:string; discord_id:string; started_at:string; ended_at:string|null};
export type Sale = {id:string; discord_id:string; customer:string; vehicle:string; plate:string; price:number; cost:number; commission:number; created_at:string; voided:boolean; commission_paid:boolean};
export type Entry = {id:string; discord_id:string; description:string; amount:number; category:string; sale_id:string|null; created_at:string};
export type Audit = {id:string; actor:string; action:string; created_at:string};
export type Data = {members:Member[]; shifts:Shift[]; sales:Sale[]; entries:Entry[]; audit:Audit[]};
export const roles:Record<Role,string>={owner:'Titolare',manager:'Responsabile',employee:'Dipendente'};
