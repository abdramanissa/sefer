import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/covers.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'story_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

/// Filters survive leaving and coming back to the tab.
class _Filters {
  static String query = '';
  static String? language;
  static String? shelf;
  static String? tag;
  static String sort = 'recent'; // recent | added | title | progress
  static bool hideFinished = false;
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Story> _visible(AppState app) {
    final q = _Filters.query.trim().toLowerCase();
    final list = app.stories.where((s) {
      if (_Filters.language != null && s.language != _Filters.language) return false;
      if (_Filters.shelf != null && !s.shelves.contains(_Filters.shelf)) return false;
      if (_Filters.tag != null && !s.tags.contains(_Filters.tag)) return false;
      if (_Filters.hideFinished && s.finishedAt != null) return false;
      if (q.isNotEmpty) {
        final hay = '${s.title} ${s.author} ${s.tags.join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    switch (_Filters.sort) {
      case 'title':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'added':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'progress':
        list.sort((a, b) => b.progress.compareTo(a.progress));
      default:
        list.sort((a, b) => (b.lastOpenedAt ?? b.createdAt).compareTo(a.lastOpenedAt ?? a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.settings;
    final stories = _visible(app);
    final cont = app.continueStory;
    final langs = app.libraryLanguages;
    final tags = app.allTags;
    final filtering = _Filters.language != null ||
        _Filters.shelf != null ||
        _Filters.tag != null ||
        _Filters.query.isNotEmpty ||
        _Filters.hideFinished;

    return PageScroll(
      id: 'library',
      children: [
        TabHeader(
          kicker: _today(),
          title: 'Library',
          actions: const [StreakPill(), SettingsAction()],
        ),
        const SizedBox(height: 20),
        if (app.stories.isEmpty)
          EmptyState(
            icon: PhosphorIconsRegular.books,
            title: 'Your library is empty',
            body: 'Sefer ships with no texts. Paste one, import files, or '
                'write your own. Everything stays on this device.',
            action: PrimaryButton(
              label: 'Add a text',
              icon: PhosphorIconsBold.plus,
              onTap: () => app.go('add'),
            ),
          )
        else ...[
          if (cont != null && !filtering) ...[
            _ContinueCard(story: cont),
            const SizedBox(height: 24),
          ],
          SearchField(
            initial: _Filters.query,
            hint: 'Search titles, authors, tags',
            onChanged: (v) => setState(() => _Filters.query = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              key: const PageStorageKey('library-filters'),
              scrollDirection: Axis.horizontal,
              children: [
                Pill(
                  label: _sortLabel(),
                  icon: PhosphorIconsBold.sortAscending,
                  onTap: _pickSort,
                ),
                const SizedBox(width: 8),
                Pill(
                  label: s.libraryView == 'grid' ? 'Grid' : 'List',
                  icon: s.libraryView == 'grid' ? PhosphorIconsBold.squaresFour : PhosphorIconsBold.rows,
                  onTap: () => app.updateSettings((x) => x.libraryView = x.libraryView == 'grid' ? 'list' : 'grid'),
                ),
                const SizedBox(width: 8),
                Pill(
                  label: 'Unfinished',
                  selected: _Filters.hideFinished,
                  onTap: () => setState(() => _Filters.hideFinished = !_Filters.hideFinished),
                ),
                if (langs.length > 1)
                  for (final l in langs) ...[
                    const SizedBox(width: 8),
                    Pill(
                      label: languageName(l),
                      selected: _Filters.language == l,
                      onTap: () => setState(() => _Filters.language = _Filters.language == l ? null : l),
                    ),
                  ],
              ],
            ),
          ),
          if (app.shelves.isNotEmpty || tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                key: const PageStorageKey('library-shelves'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final sh in app.shelves) ...[
                    Pill(
                      label: sh.name,
                      icon: PhosphorIconsFill.bookBookmark,
                      selected: _Filters.shelf == sh.id,
                      onTap: () => setState(() => _Filters.shelf = _Filters.shelf == sh.id ? null : sh.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (final t in tags) ...[
                    Pill(
                      label: '#$t',
                      selected: _Filters.tag == t,
                      onTap: () => setState(() => _Filters.tag = _Filters.tag == t ? null : t),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Pill(label: 'Manage', icon: PhosphorIconsBold.slidersHorizontal, onTap: () => showShelvesSheet(context)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SectionHeading(
            filtering ? 'Results' : 'All stories',
            trailing: '${stories.length}',
          ),
          const SizedBox(height: 14),
          if (stories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'Nothing matches these filters.',
                textAlign: TextAlign.center,
                style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary),
              ),
            )
          else if (s.libraryView == 'grid')
            _Grid(stories: stories, columns: s.gridColumns)
          else
            Column(
              children: [
                for (final st in stories)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: _ListTile(story: st)),
              ],
            ),
        ],
      ],
    );
  }

  String _sortLabel() => switch (_Filters.sort) {
    'title' => 'Title',
    'added' => 'Newest',
    'progress' => 'Progress',
    _ => 'Recent',
  };

  Future<void> _pickSort() async {
    final v = await pickOption<String>(
      context,
      title: 'Sort by',
      selected: _Filters.sort,
      items: const [
        OptionItem('recent', 'Recently read', icon: PhosphorIconsRegular.clockCounterClockwise),
        OptionItem('added', 'Newest added', icon: PhosphorIconsRegular.plusCircle),
        OptionItem('title', 'Title', icon: PhosphorIconsRegular.textAa),
        OptionItem('progress', 'Progress', icon: PhosphorIconsRegular.chartLineUp),
      ],
    );
    if (v != null) setState(() => _Filters.sort = v);
  }

  String _today() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

String? coverImagePath(AppState app, Story s) =>
    s.cover.imagePath == null ? null : app.coverPath(s.cover.imagePath!);

TextDirection storyDirection(Story s) =>
    isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr;

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final ws = app.wordStats(story);
    final started = story.lastOpenedAt != null;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(26)),
      child: Stack(
        children: [
          Positioned(
            left: -70,
            top: 20,
            child: Container(width: 176, height: 176, decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle)),
          ),
          Positioned(
            right: 40,
            top: -46,
            child: Container(width: 92, height: 92, decoration: BoxDecoration(color: c.emberSoft, shape: BoxShape.circle)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kicker(started ? 'Continue reading' : 'Up next'),
                          const SizedBox(height: 8),
                          Text(
                            story.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: storyDirection(story),
                            style: AppTheme.f(26, weight: FontWeight.w800, color: c.text, height: 1.1),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              LangBadge(story.language, full: true),
                              Text(
                                '${story.wordCount} words · ${(ws.knownRatio * 100).round()}% known',
                                style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 72,
                      height: 96,
                      child: StoryCover(
                        cover: story.cover,
                        title: story.title,
                        imagePath: coverImagePath(app, story),
                        radius: 12,
                        showTitle: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ThinProgress(value: story.progress),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: started ? 'Continue' : 'Start reading',
                  icon: PhosphorIconsFill.bookOpenText,
                  height: 52,
                  onTap: () => app.openStory(story),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.stories, required this.columns});
  final List<Story> stories;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 14.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 18,
        children: [
          for (var i = 0; i < stories.length; i++)
            SizedBox(width: w, child: Rise(index: i, child: _GridCard(story: stories[i]))),
        ],
      );
    },
  );
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final ws = app.wordStats(story);
    return Semantics(
      button: true,
      label: '${story.title}, ${languageName(story.language)}, ${(story.progress * 100).round()} percent read',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.975,
        onTap: () => app.openStory(story),
        onLongPress: () {
          Haptic.medium();
          showStoryActions(context, story);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StoryCover(cover: story.cover, title: story.title, imagePath: coverImagePath(app, story)),
                  Positioned(top: 8, left: 8, child: LangBadge(story.language)),
                  if (story.finishedAt != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: c.sage, shape: BoxShape.circle),
                        child: const Icon(PhosphorIconsBold.check, size: 11, color: Colors.white),
                      ),
                    ),
                  Positioned(left: 10, right: 10, bottom: 8, child: ThinProgress(value: story.progress, height: 3)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: storyDirection(story),
              style: AppTheme.f(14, weight: FontWeight.w700, color: c.text, height: 1.2),
            ),
            const SizedBox(height: 3),
            Text(
              '${(ws.knownRatio * 100).round()}% known · ${ws.fresh} new',
              style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final ws = app.wordStats(story);
    return Pressable(
      scale: 0.98,
      onTap: () => app.openStory(story),
      onLongPress: () {
        Haptic.medium();
        showStoryActions(context, story);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 72,
              child: StoryCover(
                cover: story.cover,
                title: story.title,
                imagePath: coverImagePath(app, story),
                radius: 10,
                showTitle: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: storyDirection(story),
                    style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      LangBadge(story.language),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${story.wordCount} words · ${(ws.knownRatio * 100).round()}% known',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ThinProgress(value: story.progress, height: 3),
                ],
              ),
            ),
            const SizedBox(width: 4),
            RoundBtn(
              icon: PhosphorIconsBold.dotsThree,
              label: 'More',
              onTap: () => showStoryActions(context, story),
            ),
          ],
        ),
      ),
    );
  }
}
