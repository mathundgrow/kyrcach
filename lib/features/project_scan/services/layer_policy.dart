import 'package:codegraph/features/project_scan/models/architecture_layer.dart';

/// Матрица разрешённых зависимостей между слоями.
///
/// Clean Architecture допускает движение «внутрь»: presentation → application →
/// domain, а data реализует интерфейсы домена. Обратные зависимости считаются
/// нарушением.
class LayerPolicy {
  const LayerPolicy();

  static const Map<ArchitectureLayer, Set<ArchitectureLayer>> _forbidden = {
    ArchitectureLayer.presentation: {},
    ArchitectureLayer.application: {ArchitectureLayer.presentation},
    ArchitectureLayer.domain: {
      ArchitectureLayer.presentation,
      ArchitectureLayer.application,
      ArchitectureLayer.data,
    },
    ArchitectureLayer.data: {ArchitectureLayer.presentation},
    ArchitectureLayer.core: {
      ArchitectureLayer.presentation,
      ArchitectureLayer.application,
      ArchitectureLayer.domain,
      ArchitectureLayer.data,
    },
    ArchitectureLayer.unknown: {},
  };

  bool isViolation(ArchitectureLayer from, ArchitectureLayer to) {
    if (from == to) return false;
    return _forbidden[from]?.contains(to) ?? false;
  }

  String describe(ArchitectureLayer from, ArchitectureLayer to) {
    return 'Слой «${from.title}» не должен зависеть от «${to.title}». '
        'Направление зависимостей должно идти внутрь: '
        'presentation → application → domain, а data реализует интерфейсы домена.';
  }
}
