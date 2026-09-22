/// Capa de persistencia local basada en `shared_preferences`.
///
/// Encapsula el acceso a `SharedPreferences` para guardar la configuracion de
/// la aplicacion y el historial de mediciones.
library;

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Object?> read(String key) => _prefs.then((p) => p.get(key));

  Future<String?> readString(String key) => _prefs.then((p) => p.getString(key));

  Future<int?> readInt(String key) => _prefs.then((p) => p.getInt(key));

  Future<double?> readDouble(String key) => _prefs.then((p) => p.getDouble(key));

  Future<bool?> readBool(String key) => _prefs.then((p) => p.getBool(key));

  Future<List<String>?> readStringList(String key) =>
      _prefs.then((p) => p.getStringList(key));

  Future<void> writeString(String key, String value) =>
      _prefs.then((p) => p.setString(key, value));

  Future<void> writeInt(String key, int value) =>
      _prefs.then((p) => p.setInt(key, value));

  Future<void> writeDouble(String key, double value) =>
      _prefs.then((p) => p.setDouble(key, value));

  Future<void> writeBool(String key, bool value) =>
      _prefs.then((p) => p.setBool(key, value));

  Future<void> writeStringList(String key, List<String> value) =>
      _prefs.then((p) => p.setStringList(key, value));
}