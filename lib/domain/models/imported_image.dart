/// A selected file, app-owned archived image, or session-only browser blob URL.
class ImportedImage {
  const ImportedImage({required this.path, required this.name});

  final String path;
  final String name;
}
