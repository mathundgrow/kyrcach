import 'package:codegraph/features/project_scan/dependency_edge.dart';

class ParsedDirective {
  const ParsedDirective({required this.uri, required this.directive});

  final String uri;
  final ImportDirective directive;
}

/// Извлекает директивы import/export из исходника Dart.
///
/// Регулярное выражение намеренно не пытается быть полноценным парсером Dart:
/// для архитектурного анализа достаточно строк, начинающихся с import/export.
class ImportDirectiveParser {
  const ImportDirectiveParser();

  static final RegExp _pattern = RegExp(
    r'''^[ \t]*(import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<ParsedDirective> parse(String source) {
    final result = <ParsedDirective>[];
    for (final match in _pattern.allMatches(source)) {
      final keyword = match.group(1);
      final uri = match.group(2);
      if (uri == null || uri.isEmpty) continue;
      result.add(
        ParsedDirective(
          uri: uri,
          directive: keyword == 'export'
              ? ImportDirective.export
              : ImportDirective.import,
        ),
      );
    }
    return result;
  }
}
