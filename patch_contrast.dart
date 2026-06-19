import 'dart:io';

void main() async {
  final file = File(r'lib\screens\ban_screen.dart');
  var content = await file.readAsString();
  int changes = 0;

  // Helper: replace & count
  String rep(String src, String from, String to) {
    if (!src.contains(from)) {
      print('  WARNING: pattern not found:\n  ---\n  $from\n  ---');
      return src;
    }
    changes++;
    return src.replaceFirst(from, to);
  }

  // ── PATCH 1: Border card trống: 0.3 → 0.5 ────────────────────────────────
  print('PATCH 1: border alpha...');
  content = rep(content,
    '                : zoneColor.withValues(alpha: 0.3),\n            width: isOccupied ? 0 : 1.5,',
    '                : zoneColor.withValues(alpha: 0.5),\n            width: isOccupied ? 0 : 1.5,',
  );

  // ── PATCH 2: Icon zone trên card trống ───────────────────────────────────
  print('PATCH 2: icon zone...');
  content = rep(content,
    '                  Icon(\n                    IconData(zone.iconCode, fontFamily: \'MaterialIcons\'),\n                    size: 20,\n                    color: isOccupied\n                        ? Colors.white.withValues(alpha: 0.8)\n                        : _parseColor(zone.color),\n                  ),',
    '                  Icon(\n                    IconData(zone.iconCode, fontFamily: \'MaterialIcons\'),\n                    size: 22,\n                    color: isOccupied\n                        ? Colors.white\n                        : _parseColor(zone.color),\n                  ),',
  );

  // ── PATCH 3: "N khách" text khi bàn có khách ─────────────────────────────
  print('PATCH 3: guest count text...');
  content = rep(content,
    '                    Text(\n                      \'\${session!.guestCount} kh\u00e1ch\',\n                      style: GoogleFonts.outfit(\n                        fontSize: 11,\n                        color: Colors.white.withValues(alpha: 0.8),\n                      ),\n                    ),',
    '                    Text(\n                      \'\${session!.guestCount} kh\u00e1ch\',\n                      style: GoogleFonts.outfit(\n                        fontSize: 11,\n                        fontWeight: FontWeight.w600,\n                        color: Colors.white.withValues(alpha: 0.95),\n                      ),\n                    ),',
  );

  // ── PATCH 4: "N chỗ" text khi bàn trống ─────────────────────────────────
  print('PATCH 4: capacity text...');
  content = rep(content,
    '                    Text(\n                      \'\${table.capacity} ch\u1ed7\',\n                      style: GoogleFonts.outfit(\n                        fontSize: 11,\n                        color: _kNavy.withValues(alpha: 0.45),\n                      ),\n                    ),',
    '                    Text(\n                      \'\${table.capacity} ch\u1ed7\',\n                      style: GoogleFonts.outfit(\n                        fontSize: 12,\n                        fontWeight: FontWeight.w600,\n                        color: _kNavy.withValues(alpha: 0.65),\n                      ),\n                    ),',
  );

  await file.writeAsString(content);
  print('\nDONE: $changes patches applied.');
}
