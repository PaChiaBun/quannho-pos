import 'dart:io';

void main() {
  final version = DateTime.now().millisecondsSinceEpoch.toString();
  print('Applying cache buster version: \$version');

  // 1. Update index.html
  final indexFile = File('build/web/index.html');
  if (indexFile.existsSync()) {
    var content = indexFile.readAsStringSync();
    content = content.replaceAll(
      'src="flutter_bootstrap.js"',
      'src="flutter_bootstrap.js?v=\$version"',
    );
    content = content.replaceAll(
      'src="flutter_bootstrap.js" async',
      'src="flutter_bootstrap.js?v=\$version" async',
    );
    indexFile.writeAsStringSync(content);
    print('Updated index.html successfully!');
  } else {
    print('Error: index.html not found!');
  }

  // 2. Update flutter_bootstrap.js
  final bootstrapFile = File('build/web/flutter_bootstrap.js');
  if (bootstrapFile.existsSync()) {
    var content = bootstrapFile.readAsStringSync();
    content = content.replaceAll(
      '"main.dart.js"',
      '"main.dart.js?v=\$version"',
    );
    bootstrapFile.writeAsStringSync(content);
    print('Updated flutter_bootstrap.js successfully!');
  } else {
    print('Error: flutter_bootstrap.js not found!');
  }
}
