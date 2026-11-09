import 'package:codegraph/features/graph/viewport_clamp.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Matrix4 _translation(double x, double y) =>
    Matrix4.identity()..translateByDouble(x, y, 0, 1);

void main() {
  const content = Size(1000, 600);
  const viewport = Size(800, 500);

  test('не меняет матрицу, если содержимое видно', () {
    final matrix = _translation(100, 50);

    final result = clampTransformToViewport(
      matrix,
      content: content,
      viewport: viewport,
    );

    expect(identical(result, matrix), isTrue);
  });

  test('не даёт увести граф вправо и вниз', () {
    final result = clampTransformToViewport(
      _translation(5000, 5000),
      content: content,
      viewport: viewport,
    );

    expect(result.storage[12], viewport.width - 96);
    expect(result.storage[13], viewport.height - 96);
  });

  test('не даёт увести граф влево и вверх', () {
    final result = clampTransformToViewport(
      _translation(-5000, -5000),
      content: content,
      viewport: viewport,
    );

    expect(result.storage[12], 96 - content.width);
    expect(result.storage[13], 96 - content.height);
  });

  test('учитывает масштаб при ограничении', () {
    final matrix = Matrix4.identity()
      ..translateByDouble(5000, 5000, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);

    final result = clampTransformToViewport(
      matrix,
      content: content,
      viewport: viewport,
    );

    expect(result.storage[12], viewport.width - 96);
    expect(result.storage[13], viewport.height - 96);
  });

  test('центрирует содержимое на слишком маленьком вьюпорте', () {
    final result = clampTransformToViewport(
      _translation(1000, 1000),
      content: const Size(100, 100),
      viewport: const Size(50, 50),
    );

    expect(result.storage[12], (96 - 100 + 50 - 96) / 2);
    expect(result.storage[13], (96 - 100 + 50 - 96) / 2);
  });

  test('держит сцену внутри вьюпорта, если она помещается целиком', () {
    final result = clampTransformToViewport(
      _translation(5000, 5000),
      content: const Size(100, 100),
      viewport: viewport,
    );

    expect(result.storage[12], viewport.width - 100);
    expect(result.storage[13], viewport.height - 100);
  });

  test('масштабирует вокруг заданной точки, не сдвигая её', () {
    final matrix = _translation(40, 30);
    final focal = const Offset(100, 100);

    final result = scaleTransformAround(matrix, 2, focal);

    expect(transformScale(result), closeTo(2, 0.0001));

    // Точка сцены, которая была под фокусом, остаётся под ним.
    final sceneFocal = MatrixUtils.transformPoint(
      Matrix4.inverted(matrix),
      focal,
    );
    final mapped = MatrixUtils.transformPoint(result, sceneFocal);
    expect(mapped.dx, closeTo(focal.dx, 0.0001));
    expect(mapped.dy, closeTo(focal.dy, 0.0001));

    // Остальные точки расходятся от фокуса в два раза.
    final origin = MatrixUtils.transformPoint(result, Offset.zero);
    expect(origin.dx, closeTo(-20, 0.0001));
    expect(origin.dy, closeTo(-40, 0.0001));
  });

  test('не создаёт новую матрицу при том же масштабе', () {
    final matrix = _translation(10, 20);

    final result = scaleTransformAround(matrix, 1, const Offset(50, 50));

    expect(identical(result, matrix), isTrue);
  });

  test('transformScale игнорирует устаревшую ось Z', () {
    final matrix = Matrix4.identity()..scaleByDouble(0.5, 0.5, 2, 1);

    expect(transformScale(matrix), closeTo(0.5, 0.0001));
  });

  test('не трогает пустые размеры', () {
    final matrix = _translation(5000, 5000);

    final result = clampTransformToViewport(
      matrix,
      content: Size.zero,
      viewport: viewport,
    );

    expect(identical(result, matrix), isTrue);
  });
}
