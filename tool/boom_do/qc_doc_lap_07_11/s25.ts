const R='/Users/banhbao/Quan Nho/quan_nho/supabase/functions/boom-chat/'; const L=await import(R+'logic.ts'); const KEY=Deno.env.get('OPENAI_API_KEY')!; const NOW=new Date('2026-10-28T09:00:00+07:00');
const st:any={};for(const k of ['a','b','c','d'])st[k.toUpperCase()]=JSON.parse(await Deno.readTextFile(R+'cham_tu_van/quan_'+k+'.json'));
const C=JSON.parse(await Deno.readTextFile('de/cau.json'));const out:any[]=[];
const g=async(m:any)=>{const res=await fetch('https://api.openai.com/v1/chat/completions',{method:'POST',headers:{Authorization:'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify({model:'gpt-6-luna',messages:m,max_completion_tokens:2600,reasoning_effort:'none'})});const j=await res.json();return L.plainAnswer(String(j.choices?.[0]?.message?.content??''));};
const job=C.flatMap((c:any)=>[0,1].map((r)=>async()=>{const s=st[c.quan];const facts=L.parseFacts(s.facts.thang_nay);const modules=L.parseModules(s.modules.thang_nay);const msgs=L.buildMessages(c.q,[],null,{huongDan:[],facts,modules,now:NOW});let a=await g(msgs);const goc=L.soLieuGoc(c.q,{facts,modules,now:NOW});const loi=L.kiemTraLoi(a,goc);if(loi.length){const b=await g([...msgs,{role:'assistant',content:a},{role:'user',content:L.noteKiem(loi)}]);if(b)a=b;}
 out.push({id:c.id+'#'+r,quan:c.quan,loai:c.loai,q:c.q,ho_so:s.mo_ta,a,kh:goc});}));
for(let i=0;i<job.length;i+=10)await Promise.all(job.slice(i,i+10).map((f:any)=>f()));
await Deno.writeTextFile('kq.json',JSON.stringify(out));
