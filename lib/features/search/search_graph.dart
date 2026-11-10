import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/project_scan/models/architecture_layer.dart';
import 'package:codegraph/features/project_scan/models/project_graph.dart';
import 'package:codegraph/features/search/search_hit.dart';

/// Локальный поиск по файлам, путям, слоям и найденным аномалиям.
///
/// Работает без сети и нейросети; для запросов вида «логика скидок»
/// поддерживает словарь архитектурных синонимов.
class SearchGraph {
  const SearchGraph();

  static const _stopWords = {
    'где',
    'что',
    'как',
    'для',
    'или',
    'при',
    'это',
    'the',
    'and',
    'with',
    'find',
    'show',
  };

  static const Map<String, ArchitectureLayer> _layerAliases = {
    'ui': ArchitectureLayer.presentation,
    'интерфейс': ArchitectureLayer.presentation,
    'экран': ArchitectureLayer.presentation,
    'виджет': ArchitectureLayer.presentation,
    'widget': ArchitectureLayer.presentation,
    'presentation': ArchitectureLayer.presentation,
    'bloc': ArchitectureLayer.application,
    'cubit': ArchitectureLayer.application,
    'состояни': ArchitectureLayer.application,
    'сценари': ArchitectureLayer.application,
    'application': ArchitectureLayer.application,
    'логик': ArchitectureLayer.domain,
    'бизнес': ArchitectureLayer.domain,
    'домен': ArchitectureLayer.domain,
    'сущност': ArchitectureLayer.domain,
    'domain': ArchitectureLayer.domain,
    'данн': ArchitectureLayer.data,
    'репозитор': ArchitectureLayer.data,
    'api': ArchitectureLayer.data,
    'сеть': ArchitectureLayer.data,
    'data': ArchitectureLayer.data,
    'ядр': ArchitectureLayer.core,
    'утилит': ArchitectureLayer.core,
    'config': ArchitectureLayer.core,
    'core': ArchitectureLayer.core,
  };

  List<SearchHit> call({
    required ProjectGraph graph,
    required GraphAnalysis analysis,
    required String query,
    int limit = 8,
  }) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return const [];

    final tokens = normalized
        .split(RegExp(r'[^a-zA-Zа-яА-Я0-9_]+'))
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toList();

    if (tokens.isEmpty) return const [];

    final layerHints = <ArchitectureLayer>{
      for (final token in tokens)
        if (_layerAliases.entries.any((entry) => token.startsWith(entry.key)))
          _layerAliases.entries
              .firstWhere((entry) => token.startsWith(entry.key))
              .value,
    };

    final hits = <SearchHit>[];

    for (final file in graph.files) {
      var score = 0;
      final reasons = <String>[];
      final name = file.name.toLowerCase();
      final path = file.relativePath.toLowerCase();
      final layerTitle = file.layer.title.toLowerCase();

      if (name == normalized) {
        score += 160;
        reasons.add('точное имя файла');
      } else if (name.contains(normalized)) {
        score += 90;
        reasons.add('имя файла');
      }
      if (path.contains(normalized)) {
        score += 55;
        if (!reasons.contains('имя файла')) reasons.add('путь');
      }

      for (final token in tokens) {
        if (name.contains(token)) {
          score += 45;
        } else if (path.contains(token)) {
          score += 24;
        }
      }

      if (layerHints.contains(file.layer)) {
        score += 35;
        reasons.add('слой ${file.layer.title}');
      }

      final fileIssues = analysis.issuesForNode(file.id);
      for (final issue in fileIssues) {
        final issueText =
            '${issue.kind.title} ${issue.kind.shortLabel} ${issue.title}'
                .toLowerCase();
        if (tokens.any(issueText.contains)) {
          score += 30;
          reasons.add('аномалия: ${issue.kind.title}');
          break;
        }
      }

      if (score == 0) continue;
      if (reasons.isEmpty) reasons.add(layerTitle);

      hits.add(
        SearchHit(
          file: file,
          reason: reasons.take(2).join(' · '),
          score: score,
        ),
      );
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.file.name.compareTo(b.file.name);
    });

    return hits.take(limit).toList(growable: false);
  }
}
