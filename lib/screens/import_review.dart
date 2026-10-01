import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/importer.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/covers.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';

/// Adds reviewed stories to the library, with [tags], and says so.
void saveImport(BuildContext context, ImportResult r, {List<String> tags = const []}) {
  final app = context.appRead;
  if (r.stories.isEmpty) return;
  for (final s in r.stories) {
    for (final t in tags) {
      if (!s.tags.contains(t)) s.tags.add(t);
    }
  }
  app.addStories(r.stories);
  Haptic.medium();
  showNotchToast(
    context,
    title: r.stories.length == 1 ? 'Added to your library' : '${r.stories.length} stories added',
    subtitle: r.stories.length == 1 ? r.stories.first.title : null,
    icon: PhosphorIconsFill.books,
    accent: context.sc.sage,
    action: r.stories.length == 1 ? 'Read' : null,
    onAction: r.stories.length == 1 ? () => app.openStory(r.stories.first) : null,
  );
}

class ImportReview extends StatelessWidget {
  const ImportReview({super.key, required this.result, required this.onSave, required this.onChanged});
  final ImportResult result;
  final VoidCallback onSave;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final n = result.stories.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(n == 0 ? 'Nothing to add' : (n == 1 ? 'Ready to add' : '$n stories ready')),
        const SizedBox(height: 12),
        for (final s in result.stories.take(30))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  SizedBox(width: 42, height: 56, child: StoryCover(cover: s.cover, title: s.title, radius: 8, showTitle: false)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Pressable(
                          scale: 0.98,
                          onTap: () async {
                            final t = await askText(context, title: 'Title', initial: s.title, action: 'Rename');
                            if (t != null && t.trim().isNotEmpty) {
                              s.title = t.trim();
                              onChanged();
                            }
                          },
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr,
                                  style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(PhosphorIconsBold.pencilSimple, size: 12, color: c.textTertiary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LangBadge(s.language),
                            Text(
                              '${s.wordCount} words · ${s.sentenceCount} sentences',
                              style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                            ),
                            if (context.app.duplicateOf(s) != null) ReviewChip('already in library', c.warn),
                            if (s.hasTranslations) ReviewChip('translated', c.sage),
                            if (s.paragraphs.any((p) => p.sentences.any((x) => x.glosses.isNotEmpty))) ReviewChip('glosses', c.info),
                            if (s.paragraphs.any((p) => p.sentences.any((x) => x.transliterations.isNotEmpty)))
                              ReviewChip('transliteration', c.brass),
                            if (s.quiz.isNotEmpty) ReviewChip('${s.quiz.length}-question quiz', c.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (n > 30)
          Text('and ${n - 30} more', textAlign: TextAlign.center, style: AppTheme.f(12.5, weight: FontWeight.w600, color: c.textTertiary)),
        if (result.problems.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsFill.warning, size: 16, color: c.warn),
                    const SizedBox(width: 8),
                    Text('Notes', style: AppTheme.f(13.5, color: c.warn)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final p in result.problems.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('· $p', style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
        if (n > 0) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            label: n == 1 ? 'Add to library' : 'Add $n stories',
            icon: PhosphorIconsBold.plus,
            onTap: onSave,
          ),
        ],
      ],
    );
  }
}

class ReviewChip extends StatelessWidget {
  const ReviewChip(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
    child: Text(label, style: AppTheme.f(10.5, weight: FontWeight.w700, color: color)),
  );
}

