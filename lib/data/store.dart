import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Where the app keeps its documents. Everything stays on the device.
abstract class Store {
  Future<Object?> read(String name);
  Future<void> write(String name, Object? json);
  Future<void> writeBytes(String name, Uint8List bytes);
  Future<Uint8List?> readBytes(String name);
  Future<void> delete(String name);

  /// Absolute path of a stored file, for `Image.file`. Null in memory.
  String? pathOf(String name);
  Future<void> wipe();
}

/// JSON files in the app's private documents directory. Writes go to a
/// temporary file first and are then renamed, so a crash mid-write never
/// leaves a half-written document.
class FileStore implements Store {
  FileStore(this.dir);
  final Directory dir;

  File _file(String name) => File('${dir.path}/$name');

  @override
  String? pathOf(String name) => _file(name).path;

  @override
  Future<Object?> read(String name) async {
    final f = _file(name);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException {
      // Keep the damaged file for inspection instead of overwriting it.
      await f.rename('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      return null;
    }
  }

  @override
  Future<void> write(String name, Object? json) async {
    final f = _file(name);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async {
    final f = _file(name);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> readBytes(String name) async {
    final f = _file(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String name) async {
    final f = _file(name);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> wipe() async {
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        await e.delete(recursive: true);
      }
    }
  }
}

/// For tests and previews.
class MemoryStore implements Store {
  final Map<String, String> docs = {};
  final Map<String, Uint8List> blobs = {};

  @override
  String? pathOf(String name) => null;

  @override
  Future<Object?> read(String name) async =>
      docs[name] == null ? null : jsonDecode(docs[name]!);

  @override
  Future<void> write(String name, Object? json) async => docs[name] = jsonEncode(json);

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async => blobs[name] = bytes;

  @override
  Future<Uint8List?> readBytes(String name) async => blobs[name];

  @override
  Future<void> delete(String name) async {
    docs.remove(name);
    blobs.remove(name);
  }

  @override
  Future<void> wipe() async {
    docs.clear();
    blobs.clear();
  }
}
