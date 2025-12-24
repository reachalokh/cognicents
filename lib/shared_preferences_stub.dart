// Stub implementation of SharedPreferences for in-memory storage only
// This avoids the iOS plugin crash while keeping the app functional
class SharedPreferences {
  static final Map<String, dynamic> _data = {};

  static Future<SharedPreferences> getInstance() async {
    return SharedPreferences._();
  }

  SharedPreferences._();

  String? getString(String key) => _data[key] as String?;
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  bool? getBool(String key) => _data[key] as bool?;
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  int? getInt(String key) => _data[key] as int?;
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  double? getDouble(String key) => _data[key] as double?;
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  Future<bool> clear() async {
    _data.clear();
    return true;
  }
}
