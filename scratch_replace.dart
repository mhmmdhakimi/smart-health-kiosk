import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('MaterialPageRoute')) {
      print('Processing ${file.path}');

      // We will handle specific patterns to be safe

      // Pattern 1: MaterialPageRoute(builder: (X) => Y)
      content = content.replaceAllMapped(
        RegExp(
          r'MaterialPageRoute\s*\(\s*builder:\s*\([^)]+\)\s*=>\s*([^,)]+)\s*\)',
        ),
        (m) => 'NoAnimRoute(page: ${m.group(1)})',
      );

      // Pattern 2: MaterialPageRoute(settings: settings, builder: (X) => Y)
      content = content.replaceAllMapped(
        RegExp(
          r'MaterialPageRoute\s*\(\s*settings:\s*(settings),\s*builder:\s*\([^)]+\)\s*=>\s*([^,)]+)\s*\)',
        ),
        (m) => 'NoAnimRoute(settings: ${m.group(1)}, page: ${m.group(2)})',
      );

      // Add import
      String importStatement = '';
      if (file.path.contains('screens') ||
          file.path.contains('widgets') ||
          file.path.contains('core')) {
        importStatement = "import '../utils/no_anim_route.dart';\n";
      } else {
        importStatement = "import 'utils/no_anim_route.dart';\n";
      }

      if (!content.contains('no_anim_route.dart')) {
        // Insert after first import
        content = content.replaceFirst('import ', '${importStatement}import ');
      }

      file.writeAsStringSync(content);
    }
  }
}
