// KAY 06/11/2026: điện thoại mở app đúng lúc lỗi mạng, module về mặc định (tắt Bếp) và không
// đọc lại, nên bàn C 4 không gửi bếp được dù mạng đã có lại vài giây sau.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bep = ModuleConfig(
  id: 'kitchen',
  label: 'Bếp',
  icon: '',
  position: 0,
  isActive: true,
);
const _banHang = ModuleConfig(
  id: 'pos',
  label: 'Bán hàng',
  icon: '',
  position: 0,
  isActive: true,
);

class _FakeRepo extends ModuleRepository {
  _FakeRepo(this.failures);
  int failures;
  int calls = 0;

  @override
  Future<({List<ModuleConfig> modules, bool ok})> load() async {
    calls++;
    if (failures > 0) {
      failures--;
      return (modules: const [_banHang], ok: false);
    }
    return (modules: const [_banHang, _bep], ok: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerWith(_FakeRepo repo) {
    final c = ProviderContainer(
      overrides: [moduleRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('đọc lỗi lần đầu: tự đọc lại và Bếp bật lại, không cần mở lại app', () async {
    final repo = _FakeRepo(1);
    final c = containerWith(repo);
    final seen = <List<String>>[];
    final sub = c.listen(activeModulesProvider, (_, next) {
      final v = next.value;
      if (v != null) seen.add([for (final m in v) m.id]);
    });
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.last, ['pos']);
    await Future<void>.delayed(
      moduleRetryDelay(0) + const Duration(milliseconds: 300),
    );
    expect(seen.last, containsAll(['pos', 'kitchen']));
    expect(repo.calls, 2);
  });

  test('đọc được ngay: không đọc thêm lần nào', () async {
    final repo = _FakeRepo(0);
    final c = containerWith(repo);
    final sub = c.listen(allModulesProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(
      moduleRetryDelay(0) + const Duration(milliseconds: 300),
    );
    expect(repo.calls, 1);
  });

  test('huỷ provider lúc đang lỗi: vòng đọc lại phải dừng', () async {
    final repo = _FakeRepo(1000);
    final c = containerWith(repo);
    final sub = c.listen(allModulesProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(repo.calls, 1);
    sub.close();
    c.dispose();
    await Future<void>.delayed(
      moduleRetryDelay(0) + const Duration(milliseconds: 300),
    );
    expect(repo.calls, 1);
  });

  test('giãn dần lần đọc lại, tối đa 30 giây', () {
    expect(moduleRetryDelay(0), const Duration(seconds: 3));
    expect(moduleRetryDelay(3), const Duration(seconds: 20));
    expect(moduleRetryDelay(50), const Duration(seconds: 30));
  });

  test('bản đúng gần nhất lưu riêng từng quán, không lẫn sang quán khác', () async {
    await ModuleRepository.saveLastGoodIds('quan-a', ['pos', 'kitchen']);
    expect(await ModuleRepository.readLastGoodIds('quan-a'), ['pos', 'kitchen']);
    expect(await ModuleRepository.readLastGoodIds('quan-b'), isNull);
  });
}
