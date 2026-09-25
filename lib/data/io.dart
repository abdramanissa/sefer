import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A file the user picked, read into memory.
class PickedFile {
  PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;

  String get extension {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  /// UTF-8 (with or without BOM), falling back to Latin-1 for old files.
  String get text {
    try {
      return utf8.decode(bytes).replaceFirst('﻿', '');
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}

class Io {
  Io._();

  /// Lets the user pick one or more text or JSON files.
  static Future<List<PickedFile>> pickTexts() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import texts',
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'text', 'md'],
    );
    return [for (final f in files) PickedFile(f.name, await f.readAsBytes())];
  }

  static Future<PickedFile?> pickJson() async {
    final f = await FilePicker.pickFile(
      dialogTitle: 'Choose a backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return f == null ? null : PickedFile(f.name, await f.readAsBytes());
  }

  static Future<PickedFile?> pickImage() async {
    final f = await FilePicker.pickFile(dialogTitle: 'Choose a cover', type: FileType.image);
    return f == null ? null : PickedFile(f.name, await f.readAsBytes());
  }

  /// Asks where to save [bytes]. Returns false when the user cancels.
  static Future<bool> save(String fileName, Uint8List bytes, {String mime = 'application/octet-stream'}) async {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mime);
    return uri != null;
  }

  static Future<bool> saveText(String fileName, String text, {String mime = 'text/plain'}) =>
      save(fileName, Uint8List.fromList(utf8.encode(text)), mime: mime);

  /// Opens the share sheet with a temporary file (for example to send a
  /// backup to another app, or a deck to AnkiDroid).
  static Future<void> shareFile(String fileName, String text, {String mime = 'text/plain'}) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsString(text, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime)], title: fileName));
  }

  static Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

/// A file-system friendly name.
String safeFileName(String s) {
  final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim();
  return cleaned.isEmpty ? 'sefer' : (cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned);
}

String stamp() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
