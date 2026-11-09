import 'package:codegraph/features/project_scan/import_directive_parser.dart';
import 'package:codegraph/features/project_scan/dependency_edge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ImportDirectiveParser();

  test('извлекает import и export, игнорирует комментарии', () {
    const source = '''
import 'a.dart';
import "b.dart" as b;
// import 'commented.dart';
export 'c.dart';

import 'package:demo/core.dart';
''';

    final directives = parser.parse(source);

    expect(directives, hasLength(4));
    expect(directives[0].uri, 'a.dart');
    expect(directives[0].directive, ImportDirective.import);
    expect(directives[1].uri, 'b.dart');
    expect(directives[2].uri, 'c.dart');
    expect(directives[2].directive, ImportDirective.export);
    expect(directives[3].uri, 'package:demo/core.dart');
  });

  test('не падает на пустом файле', () {
    expect(parser.parse(''), isEmpty);
  });
}
