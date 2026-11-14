const R='/Users/banhbao/Quan Nho/quan_nho/supabase/functions/boom-chat/';const L=await import(R+'logic.ts');const K=await import(R+'loi_khuyen.ts');
const st:any={};for(const k of ['a','b','c','d'])st[k.toUpperCase()]=JSON.parse(await Deno.readTextFile(R+'cham_tu_van/quan_'+k+'.json'));
const d=JSON.parse(await Deno.readTextFile('kq_moi3.json'));const NOW=Date.parse('2026-10-28T03:00:00Z');
let co=0,tong=0;const loai:any={};const mau:string[]=[];
for(const x of d){const f=L.parseFacts(st[x.quan].facts.thang_nay);const r=K.rutLoiKhuyen(x.a,f,NOW);if(r.length)co++;tong+=r.length;for(const y of r){const k=y.chi_so.split(':')[0];loai[k]=(loai[k]??0)+1;if(mau.length<40)mau.push(`${x.id} [${y.chi_so} mốc ${Math.round(y.moc_dau)} đo ${y.ngay_do}] ${y.noi_dung.slice(0,130)}`);}}
console.log(`câu có rút được: ${co}/${d.length}; tổng việc: ${tong}`,JSON.stringify(loai));for(const m of mau)console.log(m);
