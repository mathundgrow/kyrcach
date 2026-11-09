import 'package:codegraph/features/project_scan/architecture_layer.dart';

/// Определяет архитектурный слой по сегментам пути файла.
///
/// Правила намеренно детерминированы: один и тот же путь всегда даёт один
/// и тот же слой, поэтому анализ воспроизводим и не зависит от LLM.
class LayerClassifier {
  const LayerClassifier();

  static const Map<String, ArchitectureLayer> _segments = {
    // Ядро
    'core': ArchitectureLayer.core,
    'common': ArchitectureLayer.core,
    'shared': ArchitectureLayer.core,
    'config': ArchitectureLayer.core,
    'constants': ArchitectureLayer.core,
    'utils': ArchitectureLayer.core,
    'helpers': ArchitectureLayer.core,

    // Представление
    'presentation': ArchitectureLayer.presentation,
    'ui': ArchitectureLayer.presentation,
    'screens': ArchitectureLayer.presentation,
    'screen': ArchitectureLayer.presentation,
    'pages': ArchitectureLayer.presentation,
    'page': ArchitectureLayer.presentation,
    'widgets': ArchitectureLayer.presentation,
    'widget': ArchitectureLayer.presentation,
    'views': ArchitectureLayer.presentation,
    'theme': ArchitectureLayer.presentation,
    'styles': ArchitectureLayer.presentation,
    // Каталог lib/app — оболочка приложения и композиционный корень.
    'app': ArchitectureLayer.presentation,

    // Прикладной слой
    'application': ArchitectureLayer.application,
    'bloc': ArchitectureLayer.application,
    'blocs': ArchitectureLayer.application,
    'cubit': ArchitectureLayer.application,
    'cubits': ArchitectureLayer.application,
    'controller': ArchitectureLayer.application,
    'controllers': ArchitectureLayer.application,
    'state': ArchitectureLayer.application,
    'states': ArchitectureLayer.application,
    'di': ArchitectureLayer.application,

    // Домен
    'domain': ArchitectureLayer.domain,
    'entities': ArchitectureLayer.domain,
    'entity': ArchitectureLayer.domain,
    'usecases': ArchitectureLayer.domain,
    'use_cases': ArchitectureLayer.domain,
    'value_objects': ArchitectureLayer.domain,

    // Данные
    'data': ArchitectureLayer.data,
    'datasources': ArchitectureLayer.data,
    'data_sources': ArchitectureLayer.data,
    'repositories': ArchitectureLayer.data,
    'repository': ArchitectureLayer.data,
    'models': ArchitectureLayer.data,
    'model': ArchitectureLayer.data,
    'dto': ArchitectureLayer.data,
    'api': ArchitectureLayer.data,
    'services': ArchitectureLayer.data,
    'service': ArchitectureLayer.data,
    'storage': ArchitectureLayer.data,
    'mappers': ArchitectureLayer.data,
  };

  ArchitectureLayer classify(String relativePath) {
    final segments = relativePath
        .replaceAll('\\', '/')
        .toLowerCase()
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.isEmpty) return ArchitectureLayer.unknown;

    for (final segment in segments) {
      final layer = _segments[segment];
      if (layer != null) return layer;
    }

    final fileName = segments.last.replaceAll('.dart', '');
    if (fileName == 'main' || fileName == 'bootstrap') {
      return ArchitectureLayer.application;
    }

    return ArchitectureLayer.unknown;
  }
}
