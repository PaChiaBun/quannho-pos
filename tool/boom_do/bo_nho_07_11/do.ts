const R='/Users/banhbao/Quan Nho/quan_nho/supabase/functions/boom-chat/';const B=await import(R+'bo_nho_quan.ts');const KEY=Deno.env.get('OPENAI_API_KEY')!;
const C=JSON.parse(await Deno.readTextFile('cau.json'));const bd=(x:string)=>x.normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[đĐ]/g,'d').toLowerCase();
const goi=async(q:string)=>{const r=await fetch('https://api.openai.com/v1/chat/completions',{method:'POST',headers:{Authorization:'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify({model:'gpt-6-luna',max_completion_tokens:400,reasoning_effort:'none',messages:[{role:'user',content:B.loiDanRutGhiNho(q)}]})});const j=await r.json();return String(j.choices?.[0]?.message?.content??'');};
let dung=0,can=0,bay=0,khongCan=0,rieng=0,goiAI=0;const chi:string[]=[];
for(const r of [0,1])for(const c of C){let ghi:any[]=[];if(B.coTheRut(c.q)){goiAI++;ghi=B.locUngVien(B.docRutGhiNho(await goi(c.q)),c.la_chu);}
 const txt=ghi.map((g:any)=>bd(g.noi_dung)).join(' | ');
 if(c.nho.length){can++;const ok=c.nho.every((k:string)=>txt.includes(bd(k)));if(ok)dung++;else chi.push(`THIẾU r${r}: ${c.q.slice(0,50)} => ${txt.slice(0,120)}`);}
 else{khongCan++;if(ghi.length&&!c.rieng){bay++;chi.push(`BẬY r${r}: ${c.q.slice(0,50)} => ${txt.slice(0,120)}`);}}
 if(c.rieng&&ghi.some((g:any)=>g.muc_xem==='ca_quan'))rieng++;
 if(c.rieng&&ghi.length)chi.push(`RIÊNG r${r}: ${ghi.map((g:any)=>g.muc_xem+':'+g.noi_dung).join(' | ').slice(0,140)}`);
 if(!c.la_chu&&ghi.some((g:any)=>g.trang_thai==='xac_nhan'))chi.push('LỖI: nhân viên nói mà xác nhận');}
console.log(`nhớ đúng ${dung}/${can}; nhớ bậy ${bay}/${khongCan}; điều riêng lộ cho cả quán ${rieng}; số lần gọi AI ${goiAI}/${C.length*2}`);for(const x of chi)console.log(x);
// biết sửa: chủ quán nói dời quán, nhân viên nói dời quán
const cu=[{id:'c1',noi_dung:'Quán gần trường THCS',loai:'su_that',nguon:'chu_quan_noi',trang_thai:'xac_nhan',muc_xem:'ca_quan'}];
for(const la of [true,false]){const m=B.locUngVien(B.docRutGhiNho(await goi('tháng này tôi đã chuyển quán sang khu văn phòng rồi')),la);const k=B.keHoachGhi(m,cu as any);console.log(la?'chủ quán dời quán:':'nhân viên nói dời quán:','hết hiệu lực',k.het_hieu_luc,'ghi',k.them.map((g:any)=>g.noi_dung),'hỏi lại',k.hoi_lai?.slice(0,90)??null);}
