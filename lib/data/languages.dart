import '../text/script.dart';

class Language {
  const Language(this.code, this.name, this.native);
  final String code;
  final String name;
  final String native;

  bool get rtl => rtlLanguages.contains(code);
}

/// Languages offered in pickers. Any other code imported from JSON still
/// works; it just shows its code instead of a name.
const languages = <Language>[
  Language('ar', 'Arabic', 'العربية'),
  Language('hy', 'Armenian', 'Հայերեն'),
  Language('eu', 'Basque', 'Euskara'),
  Language('be', 'Belarusian', 'Беларуская'),
  Language('bn', 'Bengali', 'বাংলা'),
  Language('bg', 'Bulgarian', 'Български'),
  Language('ca', 'Catalan', 'Català'),
  Language('zh', 'Chinese', '中文'),
  Language('hr', 'Croatian', 'Hrvatski'),
  Language('cs', 'Czech', 'Čeština'),
  Language('da', 'Danish', 'Dansk'),
  Language('nl', 'Dutch', 'Nederlands'),
  Language('en', 'English', 'English'),
  Language('eo', 'Esperanto', 'Esperanto'),
  Language('et', 'Estonian', 'Eesti'),
  Language('fi', 'Finnish', 'Suomi'),
  Language('fr', 'French', 'Français'),
  Language('ka', 'Georgian', 'ქართული'),
  Language('de', 'German', 'Deutsch'),
  Language('el', 'Greek', 'Ελληνικά'),
  Language('grc', 'Ancient Greek', 'Ἑλληνική'),
  Language('he', 'Hebrew', 'עברית'),
  Language('hi', 'Hindi', 'हिन्दी'),
  Language('hu', 'Hungarian', 'Magyar'),
  Language('is', 'Icelandic', 'Íslenska'),
  Language('id', 'Indonesian', 'Bahasa Indonesia'),
  Language('ga', 'Irish', 'Gaeilge'),
  Language('it', 'Italian', 'Italiano'),
  Language('ja', 'Japanese', '日本語'),
  Language('kk', 'Kazakh', 'Қазақша'),
  Language('ko', 'Korean', '한국어'),
  Language('ku', 'Kurdish', 'Kurdî'),
  Language('la', 'Latin', 'Latina'),
  Language('lv', 'Latvian', 'Latviešu'),
  Language('lt', 'Lithuanian', 'Lietuvių'),
  Language('mk', 'Macedonian', 'Македонски'),
  Language('ms', 'Malay', 'Bahasa Melayu'),
  Language('mn', 'Mongolian', 'Монгол'),
  Language('no', 'Norwegian', 'Norsk'),
  Language('fa', 'Persian', 'فارسی'),
  Language('pl', 'Polish', 'Polski'),
  Language('pt', 'Portuguese', 'Português'),
  Language('ro', 'Romanian', 'Română'),
  Language('ru', 'Russian', 'Русский'),
  Language('sr', 'Serbian', 'Српски'),
  Language('sk', 'Slovak', 'Slovenčina'),
  Language('sl', 'Slovenian', 'Slovenščina'),
  Language('es', 'Spanish', 'Español'),
  Language('sw', 'Swahili', 'Kiswahili'),
  Language('sv', 'Swedish', 'Svenska'),
  Language('tl', 'Tagalog', 'Tagalog'),
  Language('th', 'Thai', 'ไทย'),
  Language('tr', 'Turkish', 'Türkçe'),
  Language('uk', 'Ukrainian', 'Українська'),
  Language('ur', 'Urdu', 'اردو'),
  Language('uz', 'Uzbek', 'Oʻzbek'),
  Language('vi', 'Vietnamese', 'Tiếng Việt'),
  Language('cy', 'Welsh', 'Cymraeg'),
  Language('yi', 'Yiddish', 'ייִדיש'),
];

Language? languageByCode(String code) {
  final base = baseLanguage(code);
  for (final l in languages) {
    if (l.code == base) return l;
  }
  return null;
}

String languageName(String code) =>
    languageByCode(code)?.name ?? code.toUpperCase();
