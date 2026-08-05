import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://kay.lpm.vn/supabase-staging',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzU0MDAwMDAwLCJleHAiOjIwNjk1MDAwMDB9.D_R6qPe-_YG6Akm85jezzunD5KrCFGLu8i5qDGd9b6c',
  );

  final storeId = '79fd45e9-14c3-4dd2-81ba-aa288a45b472'; // KAY-Rạch Giá

  try {
    // Attempt to seed demo channel
    print('Seeding demo QR channel...');
    final res = await supabase.from('qr_channels').upsert({
      'id': 'd3m00000-0000-0000-0000-000000000001',
      'store_id': storeId,
      'type': 'counter',
      'channel_code': 'DEMO',
      'name': 'Quầy Thu Ngân (Demo)',
      'is_active': true,
    });
    print('Result: $res');
  } catch (e) {
    print('Error seeding: $e');
  }
}
