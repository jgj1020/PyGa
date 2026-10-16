// Isolated PostgreSQL + actual HTTP controller, JWT guard and service.
import 'reflect-metadata';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { CommunityController } from '../dist/community/community.controller.js';
import { CommunityService } from '../dist/community/community.service.js';
import { SessionGuard } from '../dist/auth/session.guard.js';
const pg = new PGlite();
const schema = await readFile(new URL('../schema.sql',import.meta.url),'utf8');
await pg.exec(schema);
await pg.exec(schema);
const db = {
 query: async (q,p) => (await pg.query(q,p)).rows,
 transaction: fn => pg.transaction(tx => fn({query:async(q,p)=>(await tx.query(q,p)).rows})),
};
const jwt = new JwtService({secret:randomUUID()});
const module = await Test.createTestingModule({
 controllers:[CommunityController],
 providers:[CommunityService,SessionGuard,{provide:DataSource,useValue:db},{provide:JwtService,useValue:jwt}],
}).compile();
const app = module.createNestApplication();app.useLogger(false);
await app.listen(0,'127.0.0.1');
const url = await app.getUrl();
const req = async (method,path,uid,body) => {
 const res=await fetch(url+'/community'+path,{method,headers:{'Content-Type':'application/json',...(uid?{Authorization:'Bearer '+jwt.sign({sub:uid},{expiresIn:'5m'})}:{})},body:body?JSON.stringify(body):undefined});
 return {status:res.status,data:await res.json()};
};
let passed=0;
function check(condition,name){assert.ok(condition,name);passed++;console.log('PASS '+name);}
try {
 await db.query(`INSERT INTO users(nickname,email,password) VALUES ('owner','one@test.invalid','x'),('member','two@test.invalid','x'),('outsider','three@test.invalid','x')`);
 check((await req('GET','/teams',null)).status===401,'unauthenticated requests rejected');
 const make = async (overrides={}) => {
  const r=await req('POST','/teams',1,{title:'같이 하실 분',game:'VALORANT',mode:'일반',style:'편하게',mic:true,capacity:3,...overrides});
  assert.equal(r.status,201);return r.data.id;
 };
 const id=await make();
 const full=await make({title:'정원 파티',capacity:2,style:'빡겜',mic:false});
 await req('POST',`/teams/${full}/join`,2,{});
 check((await req('GET','/teams?mic=false&style='+encodeURIComponent('빡겜'),3)).data.length===1,'combined microphone and style filters');
 check((await req('GET','/teams?available=true',3)).data.every(t=>t.id!==full),'full parties excluded');
 check((await req('PATCH',`/teams/${id}/recruitment`,2,{open:false})).status===403,'non-owner cannot close');
 check((await req('PATCH',`/teams/${id}/recruitment`,1,{open:'false'})).status===400,'boolean validation');
 check((await req('POST',`/teams/${id}/join`,2,{})).status===201,'join open party');
 check((await req('PATCH',`/teams/${id}/recruitment`,1,{open:false})).status===200,'owner closes');
 check((await req('POST',`/teams/${id}/join`,3,{})).status===400,'new member blocked after close');
 check((await req('POST',`/teams/${id}/join`,2,{})).status===201,'existing member retains entry');
 check((await req('GET','/teams?mine=true',2)).data.some(t=>t.id===id && !t.recruitmentOpen),'closed party stays in member list');
 check((await req('GET',`/teams/${id}/messages`,2)).status===200,'chat history accessible after close');
 check(!(await req('GET','/teams?available=true',3)).data.some(t=>t.id===id),'closed parties excluded');
 await req('PATCH',`/teams/${id}/recruitment`,1,{open:true});
 check((await req('POST',`/teams/${id}/join`,3,{})).status===201,'reopened party accepts member');
 check((await req('GET','/teams?mic=invalid',1)).status===400,'invalid filter rejected');
 check((await req('GET','/teams?q=%25',1)).data.length===0,'literal percent search');
 await db.query(`INSERT INTO teams(title,game,mode,style,mic,capacity,owner_id) SELECT 'other ' || n,'Other','일반','편하게',true,3,1 FROM generate_series(1,105) n`);
 check((await req('GET','/teams?game=VALORANT&q='+encodeURIComponent('같이'),1)).data.some(t=>t.id===id),'filters applied before 100-row limit');
 const ranked=await make({title:'모드 필터 대상',mode:'경쟁전'});
 const modeQuery='/teams?game=VALORANT&mode='+encodeURIComponent('경쟁전')+'&style='+encodeURIComponent('편하게')+'&mic=true&available=true';
 const modeResult=await req('GET',modeQuery,3);
 check(modeResult.status===200 && modeResult.data.length===1 && modeResult.data[0].id===ranked,'mode combines with game, style, mic and availability');
 check((await req('GET','/teams?mode='+encodeURIComponent('없는 모드'),3)).data.length===0,'unmatched mode returns empty array');
 check((await req('GET','/teams?mode='+('x'.repeat(41)),3)).status===400,'oversized mode rejected');
 check((await req('GET','/teams?mode=a&mode=b',3)).status===400,'repeated mode rejected');
 check((await req('GET','/teams/counts',null)).status===401,'counts require authentication');
 const counts=await req('GET','/teams/counts',3);
 check(counts.status===200 && counts.data.find(t=>t.game==='Other')?.count===105,'counts include parties beyond list limit');
 check(counts.data.find(t=>t.game==='VALORANT')?.count===1,'full parties excluded from recruitment count');
 await req('PATCH',`/teams/${ranked}/recruitment`,1,{open:false});
 check(!(await req('GET','/teams/counts',3)).data.some(t=>t.game==='VALORANT'),'closed parties excluded from recruitment count');
 await req('PATCH',`/teams/${ranked}/recruitment`,1,{open:true});
 check((await req('GET','/teams/counts',3)).data.find(t=>t.game==='VALORANT')?.count===1,'reopening restores recruitment count');
 console.log(`${passed} checks passed; repeatable schema migration verified.`);
} finally {await app.close();await pg.close();}
