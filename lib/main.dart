import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/app_state.dart';
import 'data/store.dart';

const _fontLicenses = {
  'Nunito': 'nunito',
  'Literata': 'literata',
  'Noto Serif': 'notoserif',
  'Atkinson Hyperlegible': 'atkinsonhyperlegible',
  'Noto Sans Hebrew': 'notosanshebrew',
  'Frank Ruhl Libre': 'frankruhllibre',
  'Noto Naskh Arabic': 'notonaskharabic',
  'Amiri': 'amiri',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    for (final e in _fontLicenses.entries) {
      final text = await rootBundle.loadString('assets/fonts/OFL-${e.value}.txt');
      yield LicenseEntryWithLineBreaks([e.key], text);
    }
  });

  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/sefer');
  await dir.create(recursive: true);
  final state = AppState(FileStore(dir));
  await state.load();
  runApp(SeferApp(state: state));
}
