// lib/core/services/supabase_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Supabase Service — Sync shop registration lên cloud
// Table: shop_registrations
// ─────────────────────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // ── Config — Điền sau khi tạo project Supabase ────────────────────────────
  static const _supabaseUrl    = 'https://quannho.lpm.vn/supabase';
  static const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg0NzM5NDkwLCJleHAiOjE5NDI0MTk0OTB9.xh6_u5i7_ddq3LxAcx2ytGOnijPzRnfQ_Vkv8d0XBpw';

  static bool _initialized = false;

  /// Khởi tạo Supabase — gọi 1 lần trong main()
  static Future<void> initialize() async {
    if (_initialized) return;
    if (_supabaseUrl == 'YOUR_SUPABASE_URL') return; // Chưa config
    try {
      await Supabase.initialize(
        url:    _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      _initialized = true;
    } catch (_) {
      // Không có internet hoặc config sai — bỏ qua
    }
  }

  static SupabaseClient? get _client {
    if (!_initialized) return null;
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER SHOP — Ghi registration mới khi onboarding lần đầu
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> registerShop({
    required String shopName,
    required String ownerName,
    required String email,
    required String phone,
    String? address,
    String? city,
    String? appVersion,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('shop_registrations').upsert({
        'shop_name':   shopName,
        'owner_name':  ownerName,
        'email':       email.toLowerCase().trim(),
        'phone':       phone,
        'address':     address ?? '',
        'city':        city ?? '',
        'app_version': appVersion ?? '1.0.0',
        'installed_at': DateTime.now().toIso8601String(),
        'last_seen_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'email',  // Nếu email đã tồn tại → update thay vì insert
      );
      return true;
    } catch (_) {
      return false; // Không có mạng — không sao, data vẫn lưu local
    }
  }

  /// Update last_seen timestamp — gọi mỗi khi app khởi động
  static Future<void> updateLastSeen(String email) async {
    final client = _client;
    if (client == null || email.isEmpty) return;
    try {
      await client.from('shop_registrations').update({
        'last_seen_at': DateTime.now().toIso8601String(),
      }).eq('email', email.toLowerCase().trim());
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SQL để tạo bảng trong Supabase SQL Editor:
// (Copy paste vào Supabase → SQL Editor → Run)
// ─────────────────────────────────────────────────────────────────────────────
/*
CREATE TABLE shop_registrations (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  shop_name    text NOT NULL,
  owner_name   text DEFAULT '',
  email        text UNIQUE,
  phone        text DEFAULT '',
  address      text DEFAULT '',
  city         text DEFAULT '',
  app_version  text DEFAULT '1.0.0',
  installed_at timestamptz DEFAULT now(),
  last_seen_at timestamptz DEFAULT now()
);

-- Cho phép insert từ app (anon key)
ALTER TABLE shop_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow anon insert" ON shop_registrations
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update" ON shop_registrations
  FOR UPDATE USING (true);
*/
