/// A session-scoped reference to a selected file (or a browser blob URL).
class ImportedImage {
  const ImportedImage({required this.path, required this.name});

  final String path;
  final String name;
}
