class LocalStorage {
  final Map<String, Object?> _memory = {};

  T? read<T>(String key) {
    final value = _memory[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  Future<void> write(String key, Object? value) async {
    _memory[key] = value;
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
  }
}
