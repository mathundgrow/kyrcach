/// Архитектурный слой, к которому относится файл.
///
/// Слой определяется по пути файла (feature-first / clean architecture),
/// а не по содержимому — это делает классификацию предсказуемой.
enum ArchitectureLayer {
  presentation('Presentation', 'Представление и UI'),
  application('Application', 'Сценарии и состояние'),
  domain('Domain', 'Домен и бизнес-правила'),
  data('Data', 'Данные и инфраструктура'),
  core('Core', 'Общее ядро'),
  unknown('Other', 'Не классифицировано');

  const ArchitectureLayer(this.title, this.description);

  final String title;
  final String description;

  bool get isKnown => this != ArchitectureLayer.unknown;
}
