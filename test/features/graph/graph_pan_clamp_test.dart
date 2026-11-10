import 'dart:io';

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/graph/viewport_clamp.dart';
import 'package:codegraph/features/graph/graph_canvas.dart';
import 'package:codegraph/features/graph/graph_node_card.dart';
import 'package:codegraph/features/project_scan/widgets/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

const _files = <String, String>{
  'lib/features/demo/presentation/demo_page.dart': '''
import '../application/demo_service.dart';
import '../domain/demo_entity.dart';

class DemoPage {
  const DemoPage(this.service, this.entity);
  final DemoService service;
  final DemoEntity entity;
}
''',
  'lib/features/demo/application/demo_service.dart': '''
import '../data/demo_repository.dart';

class DemoService {
  DemoService(this.repository, this.entity);
  final DemoRepository repository;
  final DemoEntity entity;
}
''',
  'lib/features/demo/domain/demo_entity.dart': '''
import '../../../../core/utils/demo_utils.dart';

class DemoEntity {
  const DemoEntity(this.name);
  final String name;
  String get slug => DemoUtils.slug(name);
}
''',
  'lib/features/demo/data/demo_repository.dart': '''

class DemoRepository {
  DemoEntity? find(String id) => null;
}
''',
  'lib/core/utils/demo_utils.dart': '''
class DemoUtils {
  const DemoUtils._();
  static String slug(String value) => value.toLowerCase();
}
''',
};

Future<void> _writeFixture(Directory root) async {
  for (final entry in _files.entries) {
    await _writeFile(root, entry.key, entry.value);
  }
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController controller;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_pan_');
    await _writeFixture(root);

    workspace = WorkspaceController();
    await workspace.openProject(root.path);
    controller = GraphController(workspace);
  });

  tearDown(() async {
    controller.dispose();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  Future<void> pumpCanvas(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GraphController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: GraphCanvas()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Offset translation() {
    final storage = controller.transformationController.value.storage;
    return Offset(storage[12], storage[13]);
  }

  void expectInsideClampBounds(WidgetTester tester) {
    final matrix = controller.transformationController.value;
    final scale = transformScale(matrix);
    final content = controller.contentSize;
    final viewport = controller.viewportSize;

    expect(scale, greaterThan(0));
    expect(content.width, greaterThan(0));
    expect(viewport.width, greaterThan(0));

    void checkAxis(
      double value,
      double contentExtent,
      double viewportExtent,
      String axis,
    ) {
      if (contentExtent <= viewportExtent) {
        // Сцена помещается целиком — она должна остаться внутри вьюпорта.
        expect(value, greaterThanOrEqualTo(-0.01), reason: 'ось $axis');
        expect(
          value,
          lessThanOrEqualTo(viewportExtent - contentExtent + 0.01),
          reason: 'ось $axis',
        );
        return;
      }
      expect(
        value,
        greaterThanOrEqualTo(96 - contentExtent - 0.01),
        reason: 'ось $axis',
      );
      expect(
        value,
        lessThanOrEqualTo(viewportExtent - 96 + 0.01),
        reason: 'ось $axis',
      );
    }

    checkAxis(matrix.storage[12], content.width * scale, viewport.width, 'x');
    checkAxis(matrix.storage[13], content.height * scale, viewport.height, 'y');
  }

  int visibleCardCount(WidgetTester tester) {
    final viewportRect = tester.getRect(find.byType(InteractiveViewer));
    var count = 0;
    for (final element in find.byType(GraphNodeCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.overlaps(viewportRect)) count++;
    }
    return count;
  }

  Future<void> panFrom(WidgetTester tester, Offset start, Offset delta) async {
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    // Первый шаг преодолевает порог распознавания жеста.
    await gesture.moveBy(const Offset(-60, -60));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(delta / 20);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('перетаскивание карточки не уводит узел и граф за экран', (
    tester,
  ) async {
    await pumpCanvas(tester);

    final cards = find.byType(GraphNodeCard);
    // Изолированный узел (core) тоже должен попасть в раскладку.
    expect(cards, findsNWidgets(controller.visibleFiles.length));

    final firstBefore = tester.getRect(cards.at(0));
    final secondBefore = tester.getRect(cards.at(1));
    final relativeBefore = secondBefore.topLeft - firstBefore.topLeft;

    final before = translation();
    await panFrom(
      tester,
      tester.getCenter(cards.at(0)),
      const Offset(-2000, -2000),
    );
    expect((translation() - before).distance, greaterThan(1));

    final firstAfter = tester.getRect(cards.at(0));
    final secondAfter = tester.getRect(cards.at(1));
    final relativeAfter = secondAfter.topLeft - firstAfter.topLeft;

    // Узлы не должны разъезжаться: двигается вся сцена целиком.
    expect((relativeAfter - relativeBefore).distance, lessThan(0.5));
    expect(firstAfter.topLeft, isNot(firstBefore.topLeft));
    expectInsideClampBounds(tester);
    expect(visibleCardCount(tester), greaterThan(0));
  });

  testWidgets('перетаскивание пустого места не прячет граф целиком', (
    tester,
  ) async {
    await pumpCanvas(tester);

    final viewer = find.byType(InteractiveViewer);
    final viewportRect = tester.getRect(viewer);
    final cards = find.byType(GraphNodeCard);
    final cardRects = cards
        .evaluate()
        .map((element) => tester.getRect(find.byWidget(element.widget)))
        .toList();

    Offset? emptyPoint;
    for (var x = viewportRect.left + 40; x < viewportRect.right; x += 40) {
      for (
        var y = viewportRect.top + 120;
        y < viewportRect.bottom - 40;
        y += 40
      ) {
        final point = Offset(x, y);
        if (cardRects.any((rect) => rect.contains(point))) continue;
        emptyPoint = point;
        break;
      }
      if (emptyPoint != null) break;
    }
    expect(emptyPoint, isNotNull);

    final before = translation();
    await panFrom(tester, emptyPoint!, const Offset(-2000, -2000));

    expect((translation() - before).distance, greaterThan(1));
    expectInsideClampBounds(tester);
    expect(visibleCardCount(tester), greaterThan(0));
  });
}
