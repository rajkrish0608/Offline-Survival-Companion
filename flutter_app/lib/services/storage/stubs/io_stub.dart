class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
}

class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Future<void> writeAsString(String contents) async {}
  Future<String> readAsString() async => '';
  Future<void> delete() async {}
}
