import 'package:codegraph/features/project_scan/models/source_file.dart';

class SearchHit {
  const SearchHit({
    required this.file,
    required this.reason,
    required this.score,
  });

  final SourceFile file;
  final String reason;
  final int score;
}
