import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/graph/viewport_clamp.dart';
import 'package:codegraph/features/graph/graph_canvas.dart';
import 'package:codegraph/features/graph/graph_node_card.dart';
import 'package:codegraph/features/project_scan/models/architecture_layer.dart';
import 'package:codegraph/features/project_scan/widgets/workspace_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// Проект с большим числом файлов без импортов не должен терять узлы:
/// собственная сцена рисует все видимые файлы, включая изолированные.
void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController controller;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_isolated_');
    await _writeFile(root, 'pubspec.yaml', 'name: isolated_app\n');

    // Два связанных узла, как в реальном проекте с малым числом импортов.
    await _writeFile(
      root,
      'lib/features/auth/presentation/bloc/auth_bloc.dart',
      "import 'auth_event.dart';\n\nclass AuthBloc {}\n",
    );
    await _writeFile(
      root,
      'lib/features/auth/presentation/bloc/auth_event.dart',
      'class AuthEvent {}\n',
    );

    // Остальные файлы изолированы: у них нет входящих и исходящих связей.
    for (var i = 0; i < 29; i++) {
      final layer = i.isEven ? 'presentation' : 'data';
      await _writeFile(
        root,
        'lib/features/demo/$layer/file_$i.dart',
        'class File$i {}\n',
      );
    }

    workspace = WorkspaceController();
    await workspace.openProject(root.path);
    controller = GraphController(workspace);
  });

  tearDown(() async {
    controller.dispose();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  Future<void> pumpCanvas(WidgetTester tester, {GlobalKey? boundaryKey}) async {
    final app = ChangeNotifierProvider<GraphController>.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: GraphCanvas()),
      ),
    );
    await tester.pumpWidget(
      boundaryKey == null ? app : RepaintBoundary(key: boundaryKey, child: app),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Считает яркие пиксели в центральной части кадра.
  ///
  /// Это проверка реальной отрисовки, а не наличия виджетов: если сцена
  /// перестала рисоваться (как это случалось с `graphview`), в центре
  /// останется только тёмный фон и счётчик будет близок к нулю.
  Future<int> brightPixels(WidgetTester tester, GlobalKey boundaryKey) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage());
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final width = image!.width;
    final height = image.height;
    var count = 0;
    for (var y = height ~/ 5; y < height * 4 ~/ 5; y++) {
      for (var x = width ~/ 5; x < width * 4 ~/ 5; x++) {
        final index = (y * width + x) * 4;
        final r = data!.getUint8(index);
        final g = data.getUint8(index + 1);
        final b = data.getUint8(index + 2);
        if (r > 120 && g > 90 && b < 140) count++;
      }
    }
    image.dispose();
    return count;
  }

  /// Масштаб, при котором сцена целиком вписывается в свободную область.
  double fitScale() {
    final fit = math.min(
      (controller.viewportSize.width - 24) / controller.contentSize.width,
      (controller.viewportSize.height - 94) / controller.contentSize.height,
    );
    return fit * 0.95;
  }

  double minScale() => math.max(0.05, math.min(1.0, fitScale()) * 0.9);

  void expectAllCardsInsideViewport(WidgetTester tester) {
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    for (final element in find.byType(GraphNodeCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.overlaps(viewport), isTrue, reason: 'узел вне вьюпорта');
    }
  }

  void expectAtLeastOneCardVisible(WidgetTester tester) {
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final visible = find
        .byType(GraphNodeCard)
        .evaluate()
        .where(
          (element) =>
              tester.getRect(find.byWidget(element.widget)).overlaps(viewport),
        );
    expect(visible, isNotEmpty, reason: 'ни один узел не попал во вьюпорт');
  }

  Color borderColorOf(WidgetTester tester, GraphNodeCard card) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byWidget(card),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    return decoration.border!.top.color;
  }

  testWidgets('все 31 файл остаются на графе, включая изолированные', (
    tester,
  ) async {
    expect(workspace.graph?.fileCount, 31);
    expect(workspace.graph?.edgeCount, 1);

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
    await tester.pump(const Duration(milliseconds: 700));

    expect(controller.visibleFiles, hasLength(31));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    final matrix = controller.transformationController.value;
    expect(matrix.getMaxScaleOnAxis(), greaterThan(0));
    expect(matrix.storage[12].isFinite, isTrue);
    expect(matrix.storage[13].isFinite, isTrue);

    final viewport = tester.getRect(find.byType(InteractiveViewer));
    for (final element in find.byType(GraphNodeCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.overlaps(viewport), isTrue, reason: 'узел вне вьюпорта');
    }

    // Анимация вписывания не должна «уводить» узлы после появления.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
    final after = tester.getRect(find.byType(InteractiveViewer));
    for (final element in find.byType(GraphNodeCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.overlaps(after), isTrue, reason: 'узел исчез после анимации');
    }

    // Кнопки масштаба и клик по узлу не должны очищать сцену.
    await tester.tap(find.byTooltip('Приблизить'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    await tester.tap(find.byTooltip('Отдалить'));
    await tester.tap(find.byTooltip('Отдалить'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    await tester.tap(find.byType(GraphNodeCard).at(5), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    // Клик включает фокус: остаются выбранный узел и его соседи, но сцена
    // не очищается.
    expect(
      find.byType(GraphNodeCard),
      findsNWidgets(controller.displayedFiles.length),
    );
    expect(find.byType(GraphNodeCard), findsAtLeastNWidgets(1));

    controller.selectNode(null);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    // Колесо мыши: InteractiveViewer масштабирует вокруг курсора.
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -400)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 800)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    final viewportAfter = tester.getRect(find.byType(InteractiveViewer));
    for (final element in find.byType(GraphNodeCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(
        rect.overlaps(viewportAfter),
        isTrue,
        reason: 'узел исчез после масштаба или клика',
      );
    }
  });

  testWidgets('изменение размера вьюпорта не теряет узлы', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpCanvas(tester);
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    await tester.binding.setSurfaceSize(const Size(1300, 800));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));

    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
  });

  testWidgets('многократное отдаление не превращает граф в точку', (
    tester,
  ) async {
    await pumpCanvas(tester);

    for (var i = 0; i < 20; i++) {
      controller.zoomOut();
    }
    await tester.pump(const Duration(milliseconds: 300));

    final scale = transformScale(controller.transformationController.value);
    expect(scale, greaterThanOrEqualTo(minScale() - 0.001));
    expect(scale, lessThan(1.0));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
    expectAllCardsInsideViewport(tester);
  });

  testWidgets('колесо мыши не уменьшает граф ниже вписывания', (tester) async {
    await pumpCanvas(tester);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(InteractiveViewer))),
    );
    for (var i = 0; i < 8; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 600)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));

    final scale = transformScale(controller.transformationController.value);
    expect(scale, greaterThanOrEqualTo(minScale() - 0.001));
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
    expectAllCardsInsideViewport(tester);
  });

  testWidgets('граф реально отрисовывается после зума и панорамы', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    await pumpCanvas(tester, boundaryKey: boundaryKey);

    for (var i = 0; i < 12; i++) {
      controller.zoomIn();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(await brightPixels(tester, boundaryKey), greaterThan(500));

    controller.panBy(const Offset(30000, 30000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await brightPixels(tester, boundaryKey), greaterThan(500));

    for (var i = 0; i < 40; i++) {
      controller.zoomOut();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(await brightPixels(tester, boundaryKey), greaterThan(500));
  });

  testWidgets('зум и панорама не оставляют пустой экран', (tester) async {
    await pumpCanvas(tester);

    // Приближаем так, что центр вьюпорта может попасть в промежуток
    // между колонками: страховка обязана оставить хотя бы один узел.
    for (var i = 0; i < 12; i++) {
      controller.zoomIn();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expectAtLeastOneCardVisible(tester);

    controller.panBy(const Offset(20000, 20000));
    await tester.pump(const Duration(milliseconds: 200));
    expectAtLeastOneCardVisible(tester);

    controller.panBy(const Offset(-40000, -40000));
    await tester.pump(const Duration(milliseconds: 200));
    expectAtLeastOneCardVisible(tester);

    for (var i = 0; i < 30; i++) {
      controller.zoomOut();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expectAtLeastOneCardVisible(tester);
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
  });

  testWidgets('смена фильтра слоя вписывает новую сцену', (tester) async {
    await pumpCanvas(tester);
    for (var i = 0; i < 6; i++) {
      controller.zoomIn();
    }
    await tester.pump(const Duration(milliseconds: 300));

    controller.toggleLayer(ArchitectureLayer.data);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(controller.visibleFiles.length, lessThan(31));
    expect(
      find.byType(GraphNodeCard),
      findsNWidgets(controller.visibleFiles.length),
    );

    final scale = transformScale(controller.transformationController.value);
    expect(scale, closeTo(fitScale(), 0.01));
    expectAtLeastOneCardVisible(tester);
  });

  testWidgets('клик по изолированному узлу оставляет только его', (
    tester,
  ) async {
    await pumpCanvas(tester);

    final isolated = controller.visibleFiles.firstWhere(
      (file) => file.relativePath.endsWith('file_0.dart'),
    );
    controller.selectNode(isolated.id);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isFocusMode, isTrue);
    expect(controller.displayedFiles, hasLength(1));
    expect(find.byType(GraphNodeCard), findsNWidgets(1));
    expect(find.text('Фокус: file_0.dart'), findsOneWidget);

    await tester.tap(find.byTooltip('Снять выделение'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isFocusMode, isFalse);
    expect(find.byType(GraphNodeCard), findsNWidgets(31));
  });

  testWidgets('фокус оставляет выбранный файл и его связи', (tester) async {
    await pumpCanvas(tester);

    final bloc = controller.visibleFiles.firstWhere(
      (file) => file.name == 'auth_bloc.dart',
    );
    final event = controller.visibleFiles.firstWhere(
      (file) => file.name == 'auth_event.dart',
    );
    final isolated = controller.visibleFiles.firstWhere(
      (file) => file.relativePath.endsWith('file_0.dart'),
    );

    controller.selectNode(bloc.id);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isFocusMode, isTrue);
    expect(
      controller.displayedFiles.map((file) => file.id),
      unorderedEquals([bloc.id, event.id]),
    );
    expect(find.byType(GraphNodeCard), findsNWidgets(2));
    expect(
      tester
          .widgetList<GraphNodeCard>(find.byType(GraphNodeCard))
          .any((card) => card.file.id == isolated.id),
      isFalse,
    );

    // Выбранный файл импортирует event: ребро и рамка — цветом импорта.
    expect(controller.relationTo(event.id), GraphRelation.imports);
    expect(
      controller.edgeRelation(workspace.graph!.edges.first),
      GraphRelation.imports,
    );
    expect(controller.displayedEdges, hasLength(1));

    final eventCard = tester
        .widgetList<GraphNodeCard>(find.byType(GraphNodeCard))
        .firstWhere((card) => card.file.id == event.id);
    expect(borderColorOf(tester, eventCard), AppColors.importEdge);

    // Теперь выбран event: bloc становится использующим файлом.
    controller.selectNode(event.id);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.relationTo(bloc.id), GraphRelation.importer);
    expect(
      controller.edgeRelation(workspace.graph!.edges.first),
      GraphRelation.importer,
    );

    final blocCard = tester
        .widgetList<GraphNodeCard>(find.byType(GraphNodeCard))
        .firstWhere((card) => card.file.id == bloc.id);
    expect(borderColorOf(tester, blocCard), AppColors.usedByEdge);
  });
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
