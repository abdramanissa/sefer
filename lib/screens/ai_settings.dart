import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/ai.dart';
import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';

/// An [AiClient] for the current settings.
AiClient aiClientFor(AppState app) => AiClient(
  internet: app.settings.internet,
  provider: app.settings.aiProvider,
  key: app.settings.aiKey,
);

/// The internet switch, API keys and default model.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _gemini;
  late final TextEditingController _openRouter;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    final s = context.appRead.settings;
    _gemini = TextEditingController(text: s.geminiKey);
    _openRouter = TextEditingController(text: s.openRouterKey);
  }

  @override
  void dispose() {
    _gemini.dispose();
    _openRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final body = AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.45);
    final gemini = s.aiProvider == AiProviders.gemini;
    final ctl = gemini ? _gemini : _openRouter;
    return PageScroll(
      id: 'settings-ai',
      children: [
        ScreenHeader(title: 'Internet & AI', onBack: app.back),
        const SizedBox(height: 22),
        ToolGroup(
          children: [
            ToolRow(
              icon: s.internet ? PhosphorIconsRegular.globe : PhosphorIconsRegular.globeX,
              label: 'Internet',
              detail: s.internet ? 'Only when you generate a story or load models' : 'Sefer never connects',
              trailing: TinySwitch(
                value: s.internet,
                onChanged: (v) => app.updateSettings((x) => x.internet = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Everything else stays offline. With the switch on, the text you ask for is sent '
          'to the provider below, and nothing about your library, words or stats is.',
          style: body,
        ),
        const SizedBox(height: 26),
        const Kicker('Provider'),
        const SizedBox(height: 10),
        SegToggle<String>(
          value: s.aiProvider,
          expand: true,
          options: AiProviders.names,
          onChanged: (v) => app.updateSettings((x) => x.aiProvider = v),
        ),
        const SizedBox(height: 16),
        AppField(
          key: ValueKey(s.aiProvider),
          controller: ctl,
          label: '${AiProviders.names[s.aiProvider]} API key',
          hint: gemini ? 'AIza…' : 'sk-or-…',
          obscure: !_show,
          style: AppTheme.f(14, weight: FontWeight.w600, color: c.text),
          onChanged: (v) => app.updateSettings((x) {
            if (gemini) {
              x.geminiKey = v.trim();
            } else {
              x.openRouterKey = v.trim();
            }
          }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FieldIcon(
                icon: _show ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                label: _show ? 'Hide key' : 'Show key',
                onTap: () => setState(() => _show = !_show),
              ),
              _FieldIcon(
                icon: PhosphorIconsRegular.clipboardText,
                label: 'Paste key',
                onTap: () async {
                  final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
                  if (t == null || t.isEmpty) return;
                  ctl.text = t;
                  app.updateSettings((x) {
                    if (gemini) {
                      x.geminiKey = t;
                    } else {
                      x.openRouterKey = t;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get one at ${AiProviders.keyPages[s.aiProvider]}. It stays on this phone and is left out of backups.',
          style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary, height: 1.4),
        ),
        const SizedBox(height: 22),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.cpu,
              label: 'Default model',
              value: s.aiModel,
              onTap: () => pickModel(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          gemini
              ? 'Flash models are quick and cheap; Pro models write better long texts.'
              : 'OpenRouter reaches models from many companies. Prices are per million tokens in and out; a story is a few thousand.',
          style: body,
        ),
      ],
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 36, height: 24, child: Icon(icon, size: 18, color: context.sc.textSecondary)),
    ),
  );
}

/// Lets you type a model id or pick one from the provider's list.
Future<void> pickModel(BuildContext context) => showAppSheet<void>(context, (_) => const _ModelSheet());

class _ModelSheet extends StatefulWidget {
  const _ModelSheet();

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  List<AiModel>? _models;
  String? _error;
  bool _loading = false;
  String _query = '';
  late final _custom = TextEditingController(text: context.appRead.settings.aiModel);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await aiClientFor(context.appRead).models();
      if (mounted) setState(() => _models = m);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the list: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _choose(String id) {
    final app = context.appRead;
    app.updateSettings((x) {
      if (x.aiProvider == AiProviders.openRouter) {
        x.openRouterModel = id;
      } else {
        x.geminiModel = id;
      }
    });
    Navigator.pop(context);
    showNotchToast(context, title: 'Model set', subtitle: id, icon: PhosphorIconsFill.cpu);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final q = _query.toLowerCase();
    final list = (_models ?? const <AiModel>[])
        .where((m) => q.isEmpty || m.id.toLowerCase().contains(q) || m.name.toLowerCase().contains(q))
        .take(80)
        .toList();
    return SheetBody(
      title: 'Model',
      subtitle: AiProviders.names[s.aiProvider],
      children: [
        AppField(
          controller: _custom,
          hint: AiProviders.defaultModels[s.aiProvider],
          style: AppTheme.f(14, weight: FontWeight.w600, color: c.text),
          trailing: _FieldIcon(
            icon: PhosphorIconsBold.check,
            label: 'Use this model',
            onTap: () {
              final t = _custom.text.trim();
              if (t.isNotEmpty) _choose(t);
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_models == null)
          GhostButton(
            label: _loading ? 'Loading…' : 'Load the list of models',
            icon: PhosphorIconsBold.downloadSimple,
            onTap: _loading ? null : _load,
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppTheme.f(12.5, weight: FontWeight.w600, color: c.danger, height: 1.4)),
        ],
        if (_models != null) ...[
          SearchField(hint: 'Search ${_models!.length} models', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 10),
          ToolGroup(
            color: c.bgRaised2,
            children: [
              for (final m in list)
                ToolRow(
                  label: m.name,
                  detail: m.note.isEmpty ? m.id : '${m.id} · ${m.note}',
                  trailing: m.id == s.aiModel ? Icon(PhosphorIconsBold.check, size: 16, color: c.accent) : null,
                  onTap: () => _choose(m.id),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No model matches.', style: AppTheme.f(13, weight: FontWeight.w500, color: c.textTertiary)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
