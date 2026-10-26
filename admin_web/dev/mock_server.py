# Máy chủ GIẢ để xem trước trang quản trị trên máy (KHÔNG đụng production, KHÔNG nằm trong bản build).
#   bash admin_web/build.sh && python3 admin_web/dev/mock_server.py build/admin_web 8765
#   → mở http://localhost:8765/admin/ — tên đăng nhập bất kỳ, mật khẩu "dung" (giá trị giả của máy chủ giả)
# Dữ liệu mẫu cố ý có câu hỏi chứa mã HTML để kiểm trang KHÔNG chạy mã (phải hiện như chữ).
import json, sys, os, http.server, datetime, random
ROOT = sys.argv[1]; PORT = int(sys.argv[2])
now = datetime.datetime.now(datetime.timezone.utc)
def iso(d=0, h=0): return (now - datetime.timedelta(days=d, hours=h)).isoformat()
STORES = [dict(id=f"s{i}", name=f"Quán {n}", store_code=f"Q{i:03}", plan="trial", status="trial", trial_ends_at=iso(-10),
   last_active_at=iso(i), created_at=iso(i*3), owner_name=f"Chủ {n}", is_test=(i==5), orders_7d=max(0,40-i*7), orders_30d=max(0,120-i*15),
   last_order_at=(iso(i) if i<6 else None), devices=i%3+1, device_last_seen=iso(i), staff_owner=1, staff_manager=i%2, staff_other=i, menu_items=10+i*4)
   for i,n in enumerate(["Bún Nhà Làm","Cà Phê Gió","Trà Sữa Mây","Phở Hà","Cơm Tấm 79","Quán Thử Demo","Bánh Mì Cô Ba"])]
# Gói (đợt 1): s1 Pro sắp hết, s2 đang khoá, s3 sắp hết dùng thử, còn lại hết dùng thử
for r in STORES: r.update(plan='free', plan_ends_at=None, owner_phone='+84901234567')
STORES[1].update(plan='pro', status='active', plan_ends_at=iso(-5)); STORES[2].update(status='locked'); STORES[3].update(trial_ends_at=iso(-2))
NOTES = {'s0': [dict(id=1, body='Đã gọi, chủ cần hướng dẫn in bill <script>alert(1)</script>', follow_up_on=now.date().isoformat(), done_at=None, created_at=iso(1), author='Giang')]}
ACTIONS = {}
SETTINGS = {'plan_contact': 'Gọi / Zalo 0900 000 000'}
def notice(r):
    if r['status']=='locked': return None
    ends = r['plan_ends_at'] if r['plan']=='pro' else r['trial_ends_at']
    if not ends: return None
    left = (datetime.datetime.fromisoformat(ends)-datetime.datetime.now(datetime.timezone.utc)).total_seconds()/86400
    if r['plan']=='pro': return 'pro_expired' if left<=0 else 'pro_ending' if left<=7 else None
    return 'trial_expired' if left<=0 else 'trial_ending' if left<=3 else None
def snap(r): return dict(plan=r['plan'], status=r['status'], trial_ends_at=r['trial_ends_at'], plan_ends_at=r['plan_ends_at'])
# Hỗ trợ (H1 + H2): 2 yêu cầu mới (1 quên mật khẩu, 1 lỗi có chữ HTML), 1 tài khoản có PIN
ACCOUNTS = {'u1': dict(id='u1',name='Chủ Bún Nhà Làm',phone='0901234567',created_at=iso(90),has_quick_pin=True,password_kind='bcrypt',last_login=iso(1),
             stores=[dict(id='s0',name='Quán Bún Nhà Làm',code='Q000',role='owner',is_owner=True,status='trial')],support=[]),
            'u2': dict(id='u2',name='Thu ngân <b>Lan</b>',phone='0912345678',created_at=iso(10),has_quick_pin=False,password_kind='legacy',last_login=None,
             stores=[dict(id='s0',name='Quán Bún Nhà Làm',code='Q000',role='cashier',is_owner=False,status='trial')],support=[dict(action='owner_set_name',reason='Chủ quán đổi tên: Lan → Lan <i>Thu Ngân</i>',created_at=iso(1),admin='Chủ Bún Nhà Làm (chủ quán)')])}
REPORTS = [dict(id='r1',kind='forgot_password',status='open',description='Tôi quên mật khẩu, nhờ cấp lại',screen_name='Settings',created_at=iso(0,2),app_version='1.0.5',os='android',
                user_id='u1',user_name='Chủ Bún Nhà Làm',user_phone='0901234567',store_id='s0',store_name='Quán Bún Nhà Làm',store_code='Q000',admin_note=None,handled_at=None),
           dict(id='r2',kind='bug',status='open',description='In bill lỗi <script>alert(5)</script>',screen_name='Settings',created_at=iso(0,5),app_version='1.0.4',os='ios',
                user_id='u2',user_name='Thu ngân <b>Lan</b>',user_phone='0912345678',store_id='s0',store_name='Quán Bún Nhà Làm',store_code='Q000',admin_note=None,handled_at=None)]
# Thu phí (đợt A): tài khoản chưa nhập; 2 đơn chờ (1 có chữ HTML trong tên quán), 1 đơn đã trả
BILL = dict(bank=None, plans=[dict(code='pro_1m',name='Pro 1 tháng',months=1,price_vnd=99000,active=True,sort_order=1),
  dict(code='pro_6m',name='Pro 6 tháng',months=6,price_vnd=499000,active=True,sort_order=2),
  dict(code='pro_12m',name='Pro 12 tháng',months=12,price_vnd=899000,active=True,sort_order=3)],
  orders=[dict(id='b1',code='QNAB12CD',store_id='s0',store_name='Quán Bún Nhà Làm',store_code='Q000',plan_name='Pro 6 tháng',months=6,amount_vnd=499000,status='pending',created_at=iso(0,1),expires_at=iso(-1),paid_at=None,paid_amount_vnd=None,paid_source=None,paid_note=None),
          dict(id='b2',code='QNXY34ZW',store_id='s4',store_name='Cơm <img src=x onerror=alert(3)>',store_code='Q004',plan_name='Pro 1 tháng',months=1,amount_vnd=99000,status='pending',created_at=iso(0,3),expires_at=iso(-0.9),paid_at=None,paid_amount_vnd=None,paid_source=None,paid_note=None),
          dict(id='b3',code='QNPAID01',store_id='s1',store_name='Quán Cà Phê Gió',store_code='Q001',plan_name='Pro 12 tháng',months=12,amount_vnd=899000,status='paid',created_at=iso(3),expires_at=iso(2),paid_at=iso(3),paid_amount_vnd=899000,paid_source='admin',paid_note='CK VCB')])
TURNS = [dict(id=f"t{i}", created_at=iso(0,i*3), store_id="s0", source="gpt" if i%2 else "app", tool=t, question=q, answer_preview=a, answer_len=len(a),
   store_name="Quán Bún Nhà Làm", user_name="Giang", log_status="ok", rating=("down" if i==1 else None), model="gpt-4o-mini", verdict=("sai" if i==2 else None), needs_teaching=(i==2))
   for i,(t,q,a) in enumerate([
     ("revenue_summary","doanh thu hôm nay","Hôm nay Quán Bún Nhà Làm đạt 1.250.000đ từ 32 đơn hoàn thành."),
     ("advice:gpt-4o-mini+so_lieu+module","tháng này chi phí gì nhiều nhất <img src=x onerror=alert(1)>","Dạ Anh Giang ơi, tháng này chi phí lớn nhất là nguyên liệu với 61.200.000đ, chiếm 51,7% tổng chi.\n\nCần xem lại: …"),
     ("answer:gpt-4o-mini","tách bill thế nào","1. Bấm \"Tách bill\"…"),
     ("boom_tu_choi:politics","bàn chuyện chính trị","Bé Boom xin phép không trả lời ạ."),
   ])]
# Tổng quan nâng cấp: doanh thu 30 ngày có 1 ngày đột biến; gợi ý quán thử có tên chứa HTML (phải hiện như chữ)
SUGG = [dict(id=f"g{i}", name=n, code=f"G{i:03}", created_at=iso(25+i), reason=rs, orders_total=o) for i,(n,rs,o) in enumerate([
  ("aaaaa","name_junk",0),("hghhhh","name_junk",0),("Test","name_test",0),("tao test <b>x</b>","name_test",0),("Quán Nhỏ POS (Demo)","name_test",1869)])]
def extra():
    days=[dict(day=(now-datetime.timedelta(days=29-i)).date().isoformat(), n=0, revenue=0) for i in range(30)]
    for i,d in enumerate(days):
        d['n']=random.randint(20,60); d['revenue']=d['n']*random.randint(90,130)*1000
    days[8]['revenue']=95_000_000; days[8]['n']=400; days[29]['revenue']=7_500_000_000  # hôm nay đột biến hàng tỷ: nhãn trục dài
    return dict(ok=True,
      sales=dict(orders_7d=1112, revenue_7d=126_401_600, orders_prev7=1312, revenue_prev7=153_249_300, orders_30d=5965, revenue_30d=714_484_380,
                 orders_prev30=4022, revenue_prev30=498_257_700, stores_selling_7d=7, by_day=days,
                 top=[dict(id=r['id'], name=r['name'], code=r['store_code'], orders=r['orders_30d']*10, revenue=r['orders_30d']*1_200_000, orders_7d=r['orders_7d']) for r in STORES[:5]]),
      dropping=dict(total=42, rows=[dict(id=r['id'], name=r['name'], code=r['store_code'], owner_name=r['owner_name'], owner_phone=r['owner_phone'],
                 last_order_at=iso(9+i), orders_30d=30-i*4, revenue_30d=(30-i*4)*110_000, locked=r['status']=='locked') for i,r in enumerate(STORES[2:7])]
                 + [dict(id='s9', name='Cà <img src=x onerror=alert(7)>', code='Q009', owner_name='Chủ <b>X</b>', owner_phone=None, last_order_at=iso(12), orders_30d=1, revenue_30d=50000)]
                 + [dict(id=f'd{k}', name=f'Quán Phụ {k}', code=f'D{k:03}', owner_name=f'Chủ {k}', owner_phone='+84907654321', last_order_at=iso(15+k), orders_30d=1, revenue_30d=40000) for k in range(8)]),
      todo=dict(trial_ending=2, trial_expired=0, pro_ending=1, pro_expired=0, follow_ups_due=1, support_open=2, support_in_progress=0, billing_pending=2),
      test_suggest=SUGG)
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a, directory=ROOT, **k)
    def log_message(s,*a): pass
    def send_json(s, code, obj):
        b=json.dumps(obj).encode(); s.send_response(code); s.send_header('Content-Type','application/json'); s.send_header('Content-Length',str(len(b))); s.end_headers(); s.wfile.write(b)
    def do_GET(s):
        if s.path in ('/admin', '/admin/'): s.path='/index.html'
        elif s.path.startswith('/admin/'): s.path=s.path[6:]
        return super().do_GET()
    def do_POST(s):
        n=int(s.headers.get('Content-Length','0')); body=json.loads(s.rfile.read(n) or b'{}')
        p=s.path
        if p=='/api/auth/admin-jwt':
            if body.get('password')=='dung': return s.send_json(200, dict(success=True, admin_jwt='fake.jwt.x', expires_in=43200))
            return s.send_json(401, dict(success=False, message='Số điện thoại hoặc mật khẩu không đúng, hoặc tài khoản không có quyền quản trị'))
        if s.headers.get('Authorization')!='Bearer fake.jwt.x': return s.send_json(401, {})
        if p.endswith('/admin_whoami_v1'): return s.send_json(200, dict(ok=True, name='Giang'))
        if p.endswith('/admin_store_overview_v1'):
            return s.send_json(200, dict(ok=True,total=179,test_stores=1,new_today=3,new_7d=21,new_30d=166,active_7d=8,active_30d=49,sleeping=12,never_sold=118,
               new_by_day=[dict(day=(now-datetime.timedelta(days=59-i)).date().isoformat(), n=random.randint(0,12)) for i in range(60)],
               active_by_week=[dict(week_start=(now-datetime.timedelta(weeks=11-i)).date().isoformat(), n=random.randint(2,30)) for i in range(12)]))
        if p.endswith('/admin_store_list_v1'):
            rows=[r for r in STORES if body.get('p_filter')=='test' and r['is_test'] or body.get('p_filter')!='test' and not r['is_test']]
            return s.send_json(200, dict(ok=True,total=len(rows),rows=rows))
        if p.endswith('/admin_overview_extra_v1'): return s.send_json(200, extra())
        if p.endswith('/admin_set_test_store_v1'):
            SUGG[:] = [g for g in SUGG if g['id'] != body.get('p_store')]
            return s.send_json(200, dict(ok=True))
        st = next((r for r in STORES if r['id']==body.get('p_store')), None)
        if p.endswith('/admin_store_detail_v1'):
            if not st: return s.send_json(200, dict(ok=False, error='NOT_FOUND'))
            return s.send_json(200, dict(ok=True, store=dict(st, notice=notice(st)), owner=dict(name=st['owner_name'], phone=st['owner_phone'], since=iso(90)),
               modules=['pos','table','kitchen','bill_printer','report','lạ<b>x</b>'],
               accounts=[dict(name=st['owner_name'],phone=st['owner_phone'],role='owner',is_owner=True,joined=iso(30)),dict(name='Thu ngân <i>Lan</i>',phone='+84912345678',role='cashier',is_owner=False,joined=iso(10))],
               pin_staff=dict(active=4,total=6), menu_items=st['menu_items'],
               sales=dict(revenue_7d=12500000,revenue_30d=48200000,orders_7d=st['orders_7d'],orders_30d=st['orders_30d'],last_order_at=st['last_order_at']),
               sales_by_day=[dict(day=(now-datetime.timedelta(days=29-i)).date().isoformat(), orders=(o:=random.randint(0,20)), revenue=o*85000) for i in range(30)],
               devices=[dict(device='47844552-4b5d-4930-820c-c70a3a9c1185',last_seen=iso(0,1),staff='Lan',logs=812,errors=3),dict(device='2d881c6a-6044-477b-8af8-0113b2e74ec6',last_seen=iso(2),staff=None,logs=40,errors=0)],
               sessions=dict(active=2, recent=[dict(at=iso(1),last_used=iso(0,2),user='Lan',label=None,live=True),dict(at=iso(9),last_used=iso(8),user=st['owner_name'],label=None,live=False)]),
               errors=[dict(at=iso(0,3),tag='ban_screen',message='Thêm món thất bại: <img src=x onerror=alert(2)>\nSESSION_NOT_OPEN',staff='Lan',device='4784')],
               errors_14d=1, boom=dict(turns_30d=19,cost_usd_30d=0.0144,last_at=iso(1)),
               notes=NOTES.get(st['id'],[]), actions=ACTIONS.get(st['id'],[])))
        def act(kind, before, amount=None, note=None):
            ACTIONS.setdefault(st['id'],[]).insert(0, dict(action=kind,before=before,after=snap(st),amount_vnd=amount,note=note,created_at=now.isoformat(),author='Giang'))
        if p.endswith('/admin_store_extend_trial_v1'):
            if not 1<=int(body.get('p_days') or 0)<=365: return s.send_json(200, dict(ok=False,error='BAD_DAYS'))
            if st['plan']=='pro': return s.send_json(200, dict(ok=False,error='PLAN_NOT_TRIAL'))
            b=snap(st); base=max(datetime.datetime.fromisoformat(st['trial_ends_at']), datetime.datetime.now(datetime.timezone.utc))
            st['trial_ends_at']=(base+datetime.timedelta(days=int(body['p_days']))).isoformat(); act('extend_trial', b, note=body.get('p_note'))
            return s.send_json(200, dict(ok=True, store=snap(st)))
        if p.endswith('/admin_store_set_plan_v1'):
            b=snap(st); st['plan']=body['p_plan']; st['plan_ends_at']=body.get('p_ends_at') if body['p_plan']=='pro' else None
            if st['status']!='locked': st['status']='active' if st['plan']=='pro' else 'trial'
            act('set_plan', b, body.get('p_amount_vnd'), body.get('p_note')); return s.send_json(200, dict(ok=True, store=snap(st)))
        if p.endswith('/admin_store_set_locked_v1'):
            if body['p_locked'] and len((body.get('p_reason') or '').strip())<3: return s.send_json(200, dict(ok=False,error='REASON_REQUIRED'))
            b=snap(st); st['status']='locked' if body['p_locked'] else ('active' if st['plan']=='pro' else 'trial')
            act('lock' if body['p_locked'] else 'unlock', b, note=body.get('p_reason')); return s.send_json(200, dict(ok=True, store=snap(st)))
        if p.endswith('/admin_store_note_add_v1'):
            if not (body.get('p_body') or '').strip(): return s.send_json(200, dict(ok=False,error='BAD_BODY'))
            NOTES.setdefault(st['id'],[]).insert(0, dict(id=random.randint(10,99999),body=body['p_body'],follow_up_on=body.get('p_follow_up_on'),done_at=None,created_at=now.isoformat(),author='Giang'))
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_store_note_done_v1'):
            for ns in NOTES.values():
                for n in ns:
                    if n['id']==body.get('p_id'): n['done_at']=now.isoformat() if body.get('p_done') else None
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_platform_setting_set_v1'):
            SETTINGS['plan_contact']=body.get('p_value') or None; return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_support_list_v1'):
            st_=body.get('p_status') or 'open'; k=body.get('p_kind') or 'all'
            rows=[r for r in REPORTS if (st_=='all' or r['status']==st_) and (k=='all' or r['kind']==k)]
            cnt={}
            for r in REPORTS: cnt[r['status']]=cnt.get(r['status'],0)+1
            return s.send_json(200, dict(ok=True,counts=cnt,total=len(rows),rows=rows))
        if p.endswith('/admin_support_update_v1'):
            for r in REPORTS:
                if r['id']==body.get('p_id'): r.update(status=body['p_status'], admin_note=body.get('p_note') or r['admin_note'])
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_account_search_v1'):
            q=(body.get('p_q') or '').strip()
            if len(q)<3: return s.send_json(200, dict(ok=False,error='QUERY_TOO_SHORT'))
            d=''.join(c for c in q if c.isdigit())[-9:]
            rows=[a for a in ACCOUNTS.values() if (d and a['phone'][-9:]==d) or q.lower() in a['name'].lower()]
            return s.send_json(200, dict(ok=True,rows=rows))
        if p.endswith('/admin_account_detail_v1'):
            a=ACCOUNTS.get(body.get('p_user'))
            return s.send_json(200, dict(ok=True,account=a) if a else dict(ok=False,error='NOT_FOUND'))
        if p.endswith('/admin_account_reset_password_v1'):
            c=body.get('p_checks') or {}
            if not (c.get('callback') and c.get('store_info') and c.get('secret')): return s.send_json(200, dict(ok=False,error='CHECKS_REQUIRED'))
            if len((body.get('p_reason') or '').strip())<5: return s.send_json(200, dict(ok=False,error='REASON_REQUIRED'))
            a=ACCOUNTS[body['p_user']]; a['password_kind']='bcrypt'; a['support'].insert(0, dict(action='temp_password',reason=body['p_reason'],created_at=now.isoformat(),admin='Giang'))
            return s.send_json(200, dict(ok=True,temp_password='K7MQ4XPR2T'))
        if p.endswith('/admin_account_clear_pin_v1'):
            a=ACCOUNTS[body['p_user']]; a['has_quick_pin']=False; a['support'].insert(0, dict(action='clear_quick_pin',reason=body['p_reason'],created_at=now.isoformat(),admin='Giang'))
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_billing_overview_v1'):
            f=body.get('p_filter') or 'pending'; q=(body.get('p_search') or '').upper()
            rows=[o for o in BILL['orders'] if (f=='all' or o['status']==f) and (not q or q in o['code'] or q in o['store_name'].upper())]
            paid=[o for o in BILL['orders'] if o['status']=='paid']
            return s.send_json(200, dict(ok=True,bank=BILL['bank'],plans=BILL['plans'],pending_count=sum(o['status']=='pending' for o in BILL['orders']),
               paid_30d_vnd=sum(o['paid_amount_vnd'] or 0 for o in paid),paid_30d_count=len(paid),total=len(rows),rows=rows))
        if p.endswith('/admin_billing_set_bank_v1'):
            import re
            if not re.fullmatch(r'\d{6}', body.get('p_bin') or ''): return s.send_json(200, dict(ok=False,error='BAD_BIN'))
            if not re.fullmatch(r'\d{4,19}', body.get('p_account_no') or ''): return s.send_json(200, dict(ok=False,error='BAD_ACCOUNT_NO'))
            name=(body.get('p_account_name') or '').strip().upper()
            if not re.fullmatch(r'[A-Z0-9 .&-]{2,50}', name): return s.send_json(200, dict(ok=False,error='BAD_ACCOUNT_NAME'))
            BILL['bank']=dict(bin=body['p_bin'],bank_name=body.get('p_bank_name'),account_no=body['p_account_no'],account_name=name)
            return s.send_json(200, dict(ok=True,bank=BILL['bank']))
        if p.endswith('/admin_billing_set_plan_v1'):
            for pl_ in BILL['plans']:
                if pl_['code']==body.get('p_code'): pl_.update(price_vnd=body['p_price_vnd'], active=body.get('p_active', True))
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_billing_mark_paid_v1') or p.endswith('/admin_billing_cancel_order_v1'):
            o=next((x for x in BILL['orders'] if x['id']==body.get('p_order')), None)
            if not o or o['status']!='pending': return s.send_json(200, dict(ok=False,error='NOT_PENDING'))
            if p.endswith('/admin_billing_cancel_order_v1'): o['status']='cancelled'; return s.send_json(200, dict(ok=True))
            o.update(status='paid',paid_at=now.isoformat(),paid_amount_vnd=body['p_amount_vnd'],paid_source='admin',paid_note=body.get('p_note'))
            return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_plan_overview_v1'):
            ns=[notice(r) for r in STORES]
            return s.send_json(200, dict(ok=True,total=len(STORES),free=6,pro=1,trial_ending=ns.count('trial_ending'),trial_expired=ns.count('trial_expired'),
               pro_ending=ns.count('pro_ending'),pro_expired=ns.count('pro_expired'),locked=sum(r['status']=='locked' for r in STORES),
               follow_ups_due=sum(1 for v in NOTES.values() if any(n['follow_up_on'] and not n['done_at'] for n in v)),revenue_vnd_30d=sum(a['amount_vnd'] or 0 for v in ACTIONS.values() for a in v),contact=SETTINGS['plan_contact']))
        if p.endswith('/admin_plan_list_v1'):
            f=body.get('p_filter') or 'all'
            def nf(r):
                fu=min((n['follow_up_on'] for n in NOTES.get(r['id'],[]) if n['follow_up_on'] and not n['done_at']), default=None)
                return dict(r, notice=notice(r), next_follow_up=fu, last_note=(NOTES.get(r['id']) or [{}])[0].get('body'))
            rows=[nf(r) for r in STORES]
            rows=[r for r in rows if f=='all' or (f=='pro' and r['plan']=='pro') or (f=='locked' and r['status']=='locked') or (f=='follow_up' and r['next_follow_up']) or (f=='pro_due' and r['notice'] in ('pro_ending','pro_expired')) or r['notice']==f]
            return s.send_json(200, dict(ok=True,total=len(rows),rows=rows))
        if p.endswith('/admin_boom_stats_v1'): return s.send_json(200, dict(ok=True,turns=4,gpt_turns=2,stores=1,up=3,down=1,unanswered=2,blocked=1,errors=0,cost_usd=0.0123,reviewed=dict(dung=1,chua_dung=0,sai=1,teach=1)))
        if p.endswith('/admin_boom_turns_v1'): return s.send_json(200, dict(ok=True,total=len(TURNS),rows=TURNS))
        if p.endswith('/admin_boom_turn_v1'):
            t=[x for x in TURNS if x['id']==body.get('p_id')][0]
            return s.send_json(200, dict(ok=True, turn=dict(t, answer=t['answer_preview']), log=dict(status='ok',model=t['model'],rating=t['rating'],rating_reason='sai kỳ' if t['rating'] else None,input_tokens=6200,output_tokens=210,cost_usd=0.00093,latency_ms=4200),
               chunks=[dict(id='quan-ly-ban#tach-bill',title='Tách bill',module='Quản lý Bàn')] if t['tool'].startswith('answer') else [], review=dict(verdict=t['verdict'],note='Bịa nút' if t['verdict'] else None,needs_teaching=t['needs_teaching'])))
        if p.endswith('/admin_boom_review_v1'): return s.send_json(200, dict(ok=True))
        if p.endswith('/admin_boom_chunk_v1'): return s.send_json(200, dict(ok=True, chunk=dict(id=body['p_id'],title='Tách bill',module_name='Quản lý Bàn',text='1. Mở bàn\n2. Bấm …')))
        if p.endswith('/admin_boom_knowledge_v1'):
            return s.send_json(200, dict(ok=True, packs=[dict(version=202610231048,chunk_count=331,note='Boom AI v1 — bản đầu',created_at=iso(2))],
               chunks=[dict(id=f'm{i%3}#c{i}',module=['Bán hàng','Kho hàng','Quản lý Bàn'][i%3],title=f'Đoạn {i}',uses=i,ups=i//2,downs=i%2) for i in range(9)],
               modules=[dict(module='Bán hàng',questions=5,ups=2,downs=1),dict(module='Kho hàng',questions=3,ups=1,downs=0)],
               cache=[dict(id='c1',kind='guide',questions=['in tạm tính ở đâu','cách in phiếu tạm tính'],answer='Dạ {goi} ơi, mở bàn rồi bấm "In tạm tính".',status='approved',hits=12,ups=3,downs=0,note='mẫu',updated_at=iso(1)),
                      dict(id='c2',kind='advice',questions=['làm sao tăng khách buổi sáng'],answer='1. …',status='retired',hits=2,ups=0,downs=2,note='tự gỡ',updated_at=iso(2))], changelog=[dict(applied_at=iso(0,2),version='đọc 5 mục',title='Đọc số Thu Chi, Kho…',detail='CHỈ ĐỌC, theo quyền',checks='QC 3 vòng'),dict(applied_at=iso(1),version='v1',title='Boom AI v1',detail='GPT trả lời theo hướng dẫn',checks='24/24 PASS')]))
        if p.endswith('/functions/v1/boom-chat'): return s.send_json(200, dict(model='gpt-4o-mini',enabled=True,cache_on=True,logic_version='abc123def456',advice_prompt='Bạn là Bé Boom…\n1. Phạm vi…',guide_prompt='Trả lời theo ĐOẠN HƯỚNG DẪN…',refusal=dict(scope='Bé Boom chỉ hỗ trợ…')))
        return s.send_json(404, {})
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
