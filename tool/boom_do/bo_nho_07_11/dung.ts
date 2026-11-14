// Đo Boom dùng bộ nhớ: cùng câu hỏi, có / không có khối bộ nhớ; 2 lượt; đếm bằng mẫu chữ viết sẵn.
const R='/Users/banhbao/Quan Nho/quan_nho/supabase/functions/boom-chat/';const L=await import(R+'logic.ts');const B=await import(R+'bo_nho_quan.ts');const KEY=Deno.env.get('OPENAI_API_KEY')!;const NOW=new Date('2026-10-28T09:00:00+07:00');
const s=JSON.parse(await Deno.readTextFile(R+'cham_tu_van/quan_a.json'));const facts=L.parseFacts(s.facts.thang_nay),modules=L.parseModules(s.modules.thang_nay);
const g=(noi_dung:string,o:any={})=>({noi_dung,loai:'su_that',nguon:'chu_quan_noi',trang_thai:'xac_nhan',muc_xem:'ca_quan',...o});
const BN=[g('Quán là ki-ốt cạnh toà văn phòng, khách chính là dân văn phòng'),g('Combo sáng cà phê + bánh mì đã thử, khách không chuộng',{loai:'da_thu'}),g('Chủ quán không muốn giảm giá cà phê',{loai:'so_thich'}),g('Quán nghỉ Chủ nhật'),g('Đang tính cho nghỉ một bạn ca chiều',{muc_xem:'chu_quan'})];
const Q=[['làm sao tăng doanh thu',true],['nên làm combo gì',true],['ngày nào nên chạy ưu đãi',true],['nên giảm giá cà phê sữa đá không',true],['viết bài facebook giới thiệu quán',true],['ca chiều có nên bớt người không',false]];
const goi=async(m:any)=>{const r=await fetch('https://api.openai.com/v1/chat/completions',{method:'POST',headers:{Authorization:'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify({model:'gpt-6-luna',messages:m,max_completion_tokens:2600,reasoning_effort:'none'})});const j=await r.json();return L.plainAnswer(String(j.choices?.[0]?.message?.content??''));};
const out:any[]=[];const job:any[]=[];
for(const [q,laChu] of Q)for(const co of [false,true])for(const r of [0,1])job.push(async()=>{const boNho=co?B.boNhoChoBoom(BN as any,laChu as boolean,q as string):'';const msgs=L.buildMessages(q,[],null,{huongDan:[],facts,modules,now:NOW,boNho});let a=await goi(msgs);const loi=L.kiemTraLoi(a,`${L.soLieuGoc(q,{facts,modules,now:NOW})}\n${boNho}`);if(loi.length){const b=await goi([...msgs,{role:'assistant',content:a},{role:'user',content:L.noteKiem(loi)}]);if(b)a=b;}out.push({q,laChu,co,r,a});});
for(let i=0;i<job.length;i+=8)await Promise.all(job.slice(i,i+8).map((f:any)=>f()));
await Deno.writeTextFile('dung.json',JSON.stringify(out));
const bd=(x:string)=>x.normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[đĐ]/g,'d').toLowerCase();
const dem=(f:(x:any)=>boolean,co:boolean,q?:string)=>out.filter((x)=>x.co===co&&(!q||x.q===q)&&f(x)).length+'/'+out.filter((x)=>x.co===co&&(!q||x.q===q)).length;
const vp=(x:any)=>/van phong/.test(bd(x.a));
const comboSang=(x:any)=>/combo[^.\n]{0,40}(?:ca phe|banh mi)[^.\n]{0,40}(?:ca phe|banh mi)/.test(bd(x.a))&&!/da thu|khong chuong|khong hieu qua/.test(bd(x.a));
const giamCaPhe=(x:any)=>/(?:giam|bot)[^.\n]{0,25}ca phe/.test(bd(x.a))&&!/khong (?:nen )?giam|khong muon|chua nen/.test(bd(x.a));
const cn=(x:any)=>/chu nhat/.test(bd(x.a))&&/(?:uu dai|giam|combo|chay)[^.\n]{0,40}chu nhat|chu nhat[^.\n]{0,40}(?:uu dai|giam|chay)/.test(bd(x.a))&&!/nghi chu nhat|chu nhat nghi|dong cua chu nhat/.test(bd(x.a));
const khoe=(x:any)=>/(?:anh|chi|anh\/chi) (?:da|tung) (?:noi|chia se|ke)|em nho|theo (?:nhung gi|dieu) (?:anh|chi)|nhu (?:anh|chi) da noi/.test(bd(x.a));
const lo=(x:any)=>/cho nghi|nghi mot ban/.test(bd(x.a));
for(const co of [false,true]){console.log(co?'CÓ bộ nhớ':'KHÔNG bộ nhớ',
 '| nhắc văn phòng',dem(vp,co),'| khuyên lại combo sáng',dem(comboSang,co,'nên làm combo gì'),'| khuyên giảm giá cà phê',dem(giamCaPhe,co),
 '| ưu đãi Chủ nhật',dem(cn,co,'ngày nào nên chạy ưu đãi'),'| nhắc bộ nhớ kiểu khoe',dem(khoe,co),'| nhân viên thấy chuyện cho nghỉ',dem(lo,co,'ca chiều có nên bớt người không'),'| dài TB',Math.round(out.filter(x=>x.co===co).reduce((a,x)=>a+x.a.length,0)/out.filter(x=>x.co===co).length));}
