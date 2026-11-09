import 'package:flutter/rendering.dart';

/// Масштаб сцены по осям X/Y.
///
/// Матрица графа всегда масштабируется равномерно, поэтому `storage[0]`
/// надёжнее `getMaxScaleOnAxis()`: последний учитывает и ось Z, которая
/// может остаться от предыдущих операций и дать неверные границы.
double transformScale(Matrix4 matrix) => matrix.storage[0].abs();

/// Масштабирует сцену вокруг точки [focalPoint] (координаты вьюпорта).
///
/// Возвращает новую матрицу: `T(focal) · S(ratio) · T(-focal) · matrix`.
/// Такой порядок сохраняет точку под курсором/центром экрана на месте,
/// в отличие от простого домножения на диагональную матрицу.
Matrix4 scaleTransformAround(
  Matrix4 matrix,
  double targetScale,
  Offset focalPoint,
) {
  final current = transformScale(matrix);
  if (!current.isFinite || current <= 0) return matrix;
  if (!targetScale.isFinite || targetScale <= 0) return matrix;

  final ratio = targetScale / current;
  if ((ratio - 1).abs() < 0.000001) return matrix;

  final zoom = Matrix4.identity()
    ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
    ..scaleByDouble(ratio, ratio, ratio, 1)
    ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);

  return zoom..multiply(matrix);
}

/// Ограничивает перенос графа так, чтобы он не уходил целиком за экран.
///
/// Сцена использует `InteractiveViewer` с `boundaryMargin: infinity`,
/// поэтому панорамирование может увести содержимое далеко за пределы
/// вьюпорта. Если сцена больше вьюпорта, функция оставляет видимой хотя бы
/// [minVisible] пикселей содержимого по каждой оси. Если сцена помещается
/// целиком — она остаётся внутри вьюпорта.
Matrix4 clampTransformToViewport(
  Matrix4 matrix, {
  required Size content,
  required Size viewport,
  double minVisible = 96,
}) {
  if (content.isEmpty || viewport.isEmpty) return matrix;

  final scale = transformScale(matrix);
  if (!scale.isFinite || scale <= 0) return matrix;

  final contentWidth = content.width * scale;
  final contentHeight = content.height * scale;

  final x = _clampAxis(
    matrix.storage[12],
    contentExtent: contentWidth,
    viewportExtent: viewport.width,
    minVisible: minVisible,
  );
  final y = _clampAxis(
    matrix.storage[13],
    contentExtent: contentHeight,
    viewportExtent: viewport.height,
    minVisible: minVisible,
  );

  if (x == matrix.storage[12] && y == matrix.storage[13]) return matrix;

  return matrix.clone()
    ..storage[12] = x
    ..storage[13] = y;
}

double _clampAxis(
  double value, {
  required double contentExtent,
  required double viewportExtent,
  required double minVisible,
}) {
  // Сцена целиком помещается во вьюпорт — не даём увести её за края.
  if (contentExtent <= viewportExtent) {
    return value.clamp(0.0, viewportExtent - contentExtent);
  }

  final min = minVisible - contentExtent;
  final max = viewportExtent - minVisible;
  // На очень маленьком окне диапазон может схлопнуться — тогда центрируем.
  if (min > max) return (min + max) / 2;
  return value.clamp(min, max);
}
