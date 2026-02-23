class Database {
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async => 0;
  Future<List<Map<String, dynamic>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async => [];
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async => 0;
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async => 0;
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async => [];
  Future<void> close() async {}
}

enum ConflictAlgorithm { replace, ignore, abort, fail, rollback }

Future<String> getDatabasesPath() async => '';
Future<Database> openDatabase(String path, {int? version, Future<void> Function(Database, int)? onCreate, Future<void> Function(Database, int, int)? onUpgrade}) async => Database();
