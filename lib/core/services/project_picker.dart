import 'package:file_selector/file_selector.dart';

class ProjectPicker {
  const ProjectPicker._();

  static Future<String?> pickDirectory() {
    return getDirectoryPath(confirmButtonText: 'Анализировать');
  }
}
