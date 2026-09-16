import 'package:local_reviews/vault/secure_seed_storage.dart';

class FakeSeedKeyValueStore implements SeedKeyValueStore {
  FakeSeedKeyValueStore({this.failWith});

  final Object? failWith;
  String? value;

  @override
  Future<String?> read() async {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<void> write(String newValue) async {
    if (failWith != null) throw failWith!;
    value = newValue;
  }

  @override
  Future<void> delete() async {
    if (failWith != null) throw failWith!;
    value = null;
  }
}
