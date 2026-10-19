// Cloudflare Turnstile cho web (dart:js_interop, không dùng dart:html).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

const _scriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

JSObject get _doc => globalContext['document'] as JSObject;

Future<bool> _ensureScript() async {
  if (globalContext.has('turnstile')) return true;
  final existing = _doc.callMethod<JSAny?>(
    'getElementById'.toJS,
    'cf-turnstile-script'.toJS,
  );
  if (existing == null || existing.isUndefinedOrNull) {
    final s = _doc.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
    s['id'] = 'cf-turnstile-script'.toJS;
    s['src'] = _scriptUrl.toJS;
    s['async'] = true.toJS;
    s['defer'] = true.toJS;
    (_doc['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, s);
  }
  for (var i = 0; i < 100; i++) {
    if (globalContext.has('turnstile')) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

/// Chạy Turnstile (thường vô hình; chỉ hiện ô tick khi nghi ngờ).
/// Trả token, hoặc null nếu thất bại/hết thời gian.
Future<String?> solveTurnstile(String siteKey) async {
  if (siteKey.isEmpty || !await _ensureScript()) return null;
  final completer = Completer<String?>();
  void finish(String? token) {
    if (!completer.isCompleted) completer.complete(token);
  }

  final box = _doc.callMethod<JSObject>('createElement'.toJS, 'div'.toJS);
  final st = box['style'] as JSObject;
  st['position'] = 'fixed'.toJS;
  st['left'] = '50%'.toJS;
  st['bottom'] = '90px'.toJS;
  st['transform'] = 'translateX(-50%)'.toJS;
  st['zIndex'] = '2147483647'.toJS;
  (_doc['body'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, box);

  JSAny? widgetId;
  final turnstile = globalContext['turnstile'] as JSObject;
  try {
    final opts = JSObject();
    opts['sitekey'] = siteKey.toJS;
    opts['appearance'] = 'interaction-only'.toJS;
    opts['callback'] = ((JSAny? t) {
      finish(t is JSString ? t.toDart : null);
    }).toJS;
    opts['error-callback'] = ((JSAny? _) => finish(null)).toJS;
    opts['expired-callback'] = ((JSAny? _) => finish(null)).toJS;
    widgetId = turnstile.callMethod<JSAny?>('render'.toJS, box, opts);
    return await completer.future.timeout(
      const Duration(seconds: 40),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  } finally {
    try {
      if (widgetId != null) {
        turnstile.callMethod<JSAny?>('remove'.toJS, widgetId);
      }
    } catch (_) {}
    try {
      box.callMethod<JSAny?>('remove'.toJS);
    } catch (_) {}
  }
}
