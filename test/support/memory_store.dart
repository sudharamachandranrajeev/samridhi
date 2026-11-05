import 'package:samridhi/security/pin_lock.dart';

/// In-memory [SecretStore] for tests (no platform channel).
class MemoryStore implements SecretStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}
