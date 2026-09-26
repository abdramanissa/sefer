import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/common.dart';
import '../widgets/covers.dart';
import '../widgets/ui_kit.dart';
import 'story_actions.dart';

String? coverImagePath(AppState app, Story s) =>
    s.cover.imagePath == null ? null : app.coverPath(s.cover.imagePath!);

TextDirection storyDirection(Story s) =>
    isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr;

/// Filters picked in the options sheet. They last while the app is open;
/// view, sort and grouping are saved in settings.
class _Filters {
  static String query = '';
  static String? language;
  static String? shelf;
  static String? tag;

  static bool get picked => language != null || shelf != null || tag != null;
  static bool get any => query.isNotEmpty || picked;

  static void clear() {
    language = null;
    shelf = null;
    tag = null;
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Story> _visible(AppState app) {
    final s = app.settings;
    final q = _Filters.query.trim().toLowerCase();
    final list = app.visibleStories.where((st) {
      if (_Filters.language != null && st.language != _Filters.language) return false;
      if (_Filters.shelf != null && !st.shelves.contains(_Filters.shelf)) return false;
      if (_Filters.tag != null && !st.tags.contains(_Filters.tag)) return false;
      if (s.libraryHideFinished && st.finishedAt != null) return false;
      if (q.isNotEmpty) {
        final hay = '${st.title} ${st.author} ${st.tags.join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    int by(Story a, Story b) => switch (s.librarySort) {
      'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      'added' => b.createdAt.compareTo(a.createdAt),
      'progress' => b.progress.compareTo(a.progress),
      'length' => a.wordCount.compareTo(b.wordCount),
      _ => (b.lastOpenedAt ?? b.createdAt).compareTo(a.lastOpenedAt ?? a.createdAt),
    };
    list.sort((a, b) {
      if (s.libraryFavoritesFirst && a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return by(a, b);
    });
    return list;
  }

  /// Splits [list] into titled groups.
  List<(String, List<Story>)> _groups(AppState app, List<Story> list, String group) {
    switch (group) {
      case 'language':
        final m = <String, List<Story>>{};
        for (final s in list) {
          m.putIfAbsent(s.language, () => []).add(s);
        }
        return [for (final e in m.entries) (languageName(e.key), e.value)];
      case 'shelf':
        final out = <(String, List<Story>)>[];
        for (final sh in app.shelves) {
          final l = list.where((s) => s.shelves.contains(sh.id)).toList();
          if (l.isNotEmpty) out.add((sh.name, l));
        }
        final loose = list.where((s) => s.shelves.isEmpty).toList();
        if (loose.isNotEmpty) out.add((out.isEmpty ? 'All stories' : 'Not on a shelf', loose));
        return out;
      default:
        return [(_Filters.any ? 'Results' : 'All stories', list)];
    }
  }

  /// Shelf view: what you're reading, favourites, then one row per language
  /// (or per shelf when grouping by shelf).
  List<(String, List<Story>)> _shelfRows(AppState app, List<Story> list) {
    final reading = list.where((s) => s.lastOpenedAt != null && s.finishedAt == null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    final favs = list.where((s) => s.favorite).toList();
    final group = app.settings.libraryGroup == 'shelf' ? 'shelf' : 'language';
    return [
      if (reading.isNotEmpty) ('Reading', reading),
      if (favs.isNotEmpty) ('Favourites', favs),
      ..._groups(app, list, group),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final feel = context.feel;
    final s = app.settings;
    final all = app.visibleStories;
    final view = s.libraryView;
    final cont = app.continueStory;

    final header = <Widget>[
      TabHeader(kicker: _today(), title: 'Library', actions: const [LanguagePill(), StreakPill()]),
      SizedBox(height: feel.gap + 6),
    ];

    if (all.isEmpty) {
      return PageScroll(
        id: 'library',
        children: [
          ...header,
          EmptyState(
            icon: PhosphorIconsRegular.books,
            title: app.scoped && app.stories.isNotEmpty
                ? 'No ${languageName(app.activeLanguage!)} stories yet'
                : 'Your library is empty',
            body: 'Sefer ships with no texts. Paste one, import files, or '
                'write your own. Everything stays on this device.',
            action: PrimaryButton(label: 'Add a text', icon: PhosphorIconsBold.plus, onTap: () => app.go('add')),
          ),
        ],
      );
    }

    final list = _visible(app);
    final top = <Widget>[
      ...header,
      if (s.showContinueCard && cont != null && app.inScope(cont.language) && !_Filters.any) ...[
        _ContinueCard(story: cont),
        SizedBox(height: feel.gap + 8),
      ],
      Row(
        children: [
          Expanded(
            child: SearchField(
              initial: _Filters.query,
              hint: 'Search your library',
              onChanged: (v) => setState(() => _Filters.query = v),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Library options',
            excludeSemantics: true,
            child: Pressable(
              scale: 0.9,
              onTap: () async {
                await showLibraryOptions(context);
                if (mounted) setState(() {});
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _Filters.picked ? c.ember : c.bgRaised,
                  borderRadius: BorderRadius.circular(feel.pill(48)),
                ),
                child: Icon(PhosphorIconsBold.slidersHorizontal, size: 18, color: _Filters.picked ? c.onEmber : c.text),
              ),
            ),
          ),
        ],
      ),
      if (_Filters.picked) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_Filters.language != null)
              Pill(label: languageName(_Filters.language!), icon: PhosphorIconsBold.x, selected: true, onTap: () => setState(() => _Filters.language = null)),
            if (_Filters.shelf != null)
              Pill(
                label: app.shelves.where((x) => x.id == _Filters.shelf).firstOrNull?.name ?? 'Shelf',
                icon: PhosphorIconsBold.x,
                selected: true,
                onTap: () => setState(() => _Filters.shelf = null),
              ),
            if (_Filters.tag != null)
              Pill(label: '#${_Filters.tag}', icon: PhosphorIconsBold.x, selected: true, onTap: () => setState(() => _Filters.tag = null)),
          ],
        ),
      ],
      SizedBox(height: feel.section - 8),
    ];

    if (list.isEmpty) {
      return PageScroll(
        id: 'library',
        children: [
          ...top,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Nothing matches.',
              textAlign: TextAlign.center,
              style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary),
            ),
          ),
          if (_Filters.any)
            Center(
              child: GhostButton(
                label: 'Clear filters',
                expand: false,
                onTap: () => setState(() {
                  _Filters.clear();
                  _Filters.query = '';
                }),
              ),
            ),
        ],
      );
    }

    final groups = view == 'shelf' ? _shelfRows(app, list) : _groups(app, list, s.libraryGroup);
    final slivers = <Widget>[];
    for (final (title, items) in groups) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: feel.gap, top: slivers.isEmpty ? 0 : feel.section - feel.gap),
          child: SectionHeading(title, trailing: feel.meta ? '${items.length}' : null),
        ),
      ));
      slivers.add(switch (view) {
        'shelf' => SliverToBoxAdapter(child: _ShelfRow(stories: items)),
        'list' => _listSliver(items, (st) => _ListTile(story: st)),
        'titles' => _listSliver(items, (st) => _TitleRow(story: st)),
        _ => _GridSliver(stories: items, columns: s.gridColumns),
      });
    }
    return PageScroll(id: 'library', slivers: slivers, children: top);
  }

  Widget _listSliver(List<Story> items, Widget Function(Story) item) => SliverList.builder(
    itemCount: items.length,
    itemBuilder: (context, i) => Padding(
      padding: EdgeInsets.only(bottom: context.feel.gap * 0.7),
      child: item(items[i]),
    ),
  );

  String _today() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

// ------------------------------------------------------------------ options

/// One sheet for how the library looks and what it shows.
Future<void> showLibraryOptions(BuildContext context) => showAppSheet<void>(
  context,
  (ctx) => StatefulBuilder(
    builder: (ctx, setSheet) {
      final app = ctx.app;
      final s = app.settings;
      final c = ctx.sc;
      void set(void Function(Settings) f) => app.updateSettings(f);
      void filter(void Function() f) => setSheet(f);
      final langs = app.libraryLanguages.where(app.inScope).toList();
      return SheetBody(
        title: 'Library',
        children: [
          const Kicker('View'),
          const SizedBox(height: 8),
          SegToggle<String>(
            value: s.libraryView,
            expand: true,
            options: const {'grid': 'Covers', 'shelf': 'Shelves', 'list': 'List', 'titles': 'Titles'},
            onChanged: (v) => set((x) => x.libraryView = v),
          ),
          const SizedBox(height: 14),
          ToolGroup(
            color: c.bgRaised2,
            radius: 18,
            children: [
              if (s.libraryView == 'grid')
                ToolRow(
                  label: 'Covers per row',
                  trailing: SegToggle<int>(value: s.gridColumns, options: const {2: '2', 3: '3'}, onChanged: (v) => set((x) => x.gridColumns = v)),
                ),
              ToolRow(
                label: 'Sort',
                value: const {'recent': 'Recently read', 'added': 'Newest', 'title': 'Title', 'progress': 'Progress', 'length': 'Shortest'}[s.librarySort],
                onTap: () async {
                  final v = await pickOption<String>(ctx, title: 'Sort by', selected: s.librarySort, items: const [
                    OptionItem('recent', 'Recently read', icon: PhosphorIconsRegular.clockCounterClockwise),
                    OptionItem('added', 'Newest added', icon: PhosphorIconsRegular.plusCircle),
                    OptionItem('title', 'Title', icon: PhosphorIconsRegular.textAa),
                    OptionItem('progress', 'Progress', icon: PhosphorIconsRegular.chartLineUp),
                    OptionItem('length', 'Shortest first', icon: PhosphorIconsRegular.ruler),
                  ]);
                  if (v != null) set((x) => x.librarySort = v);
                },
              ),
              ToolRow(
                label: 'Group by',
                value: const {'none': 'Nothing', 'language': 'Language', 'shelf': 'Shelf'}[s.libraryGroup],
                onTap: () async {
                  final v = await pickOption<String>(ctx, title: 'Group by', selected: s.libraryGroup, items: const [
                    OptionItem('none', 'Nothing'),
                    OptionItem('language', 'Language'),
                    OptionItem('shelf', 'Shelf'),
                  ]);
                  if (v != null) set((x) => x.libraryGroup = v);
                },
              ),
              ToolRow(label: 'Favourites first', trailing: TinySwitch(value: s.libraryFavoritesFirst, onChanged: (v) => set((x) => x.libraryFavoritesFirst = v))),
              ToolRow(label: 'Hide finished', trailing: TinySwitch(value: s.libraryHideFinished, onChanged: (v) => set((x) => x.libraryHideFinished = v))),
              ToolRow(label: 'Known % on stories', trailing: TinySwitch(value: s.libraryShowStats, onChanged: (v) => set((x) => x.libraryShowStats = v))),
              ToolRow(label: 'Continue-reading card', trailing: TinySwitch(value: s.showContinueCard, onChanged: (v) => set((x) => x.showContinueCard = v))),
            ],
          ),
          if (langs.length > 1) ...[
            const SizedBox(height: 18),
            const Kicker('Language'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in langs)
                Pill(
                  label: languageName(l),
                  selected: _Filters.language == l,
                  onTap: () => filter(() => _Filters.language = _Filters.language == l ? null : l),
                ),
            ]),
          ],
          if (app.shelves.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Kicker('Shelf'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sh in app.shelves)
                Pill(
                  label: sh.name,
                  icon: PhosphorIconsFill.bookBookmark,
                  selected: _Filters.shelf == sh.id,
                  onTap: () => filter(() => _Filters.shelf = _Filters.shelf == sh.id ? null : sh.id),
                ),
            ]),
          ],
          if (app.allTags.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Kicker('Tag'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in app.allTags)
                Pill(
                  label: '#$t',
                  selected: _Filters.tag == t,
                  onTap: () => filter(() => _Filters.tag = _Filters.tag == t ? null : t),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GhostButton(label: 'Shelves and tags', icon: PhosphorIconsBold.slidersHorizontal, onTap: () => showShelvesSheet(ctx)),
              ),
              if (_Filters.picked) ...[
                const SizedBox(width: 10),
                Expanded(child: GhostButton(label: 'Clear filters', onTap: () => filter(_Filters.clear))),
              ],
            ],
          ),
        ],
      );
    },
  ),
);

// ------------------------------------------------------------------ items

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final feel = context.feel;
    return SoftCard(
      radius: 26,
      onTap: () => app.openStory(story),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 74,
            child: StoryCover(cover: story.cover, title: story.title, imagePath: coverImagePath(app, story), radius: feel.r(10), showTitle: false),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feel.kickers) ...[Kicker(story.lastOpenedAt == null ? 'Up next' : 'Continue'), const SizedBox(height: 4)],
                Text(story.title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: storyDirection(story), style: AppTheme.f(17, weight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 8),
                ThinProgress(value: story.progress),
                const SizedBox(height: 6),
                Text('${app.minutesLeft(story)} min left', style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle),
            child: Icon(PhosphorIconsFill.play, size: 18, color: c.onEmber),
          ),
        ],
      ),
    );
  }
}

class _GridSliver extends StatelessWidget {
  const _GridSliver({required this.stories, required this.columns});
  final List<Story> stories;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final feel = context.feel;
    final app = context.app;
    final extra = feel.meta && app.settings.libraryShowStats ? 50.0 : 46.0;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final gap = feel.gap;
        final w = (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap + 4,
            mainAxisExtent: w * 4 / 3 + extra * MediaQuery.textScalerOf(context).scale(1),
          ),
          itemCount: stories.length,
          itemBuilder: (context, i) => _GridCard(story: stories[i]),
        );
      },
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final feel = context.feel;
    final showStats = feel.meta && app.settings.libraryShowStats;
    final ws = showStats ? app.wordStats(story) : null;
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
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryCover(cover: story.cover, title: story.title, imagePath: coverImagePath(app, story), radius: feel.r(16)),
                    if (feel.decor && !app.scoped) Positioned(top: 8, left: 8, child: LangBadge(story.language)),
                    if (story.favorite) const Positioned(top: 8, right: 8, child: _Badge(icon: PhosphorIconsFill.star)),
                    if (story.finishedAt != null) Positioned(bottom: 16, right: 8, child: _Badge(icon: PhosphorIconsBold.check, color: c.sage)),
                    Positioned(left: 10, right: 10, bottom: 8, child: ThinProgress(value: story.progress, height: 3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              story.title,
              maxLines: showStats ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textDirection: storyDirection(story),
              style: AppTheme.f(14, weight: FontWeight.w700, color: c.text, height: 1.2),
            ),
            if (ws != null) ...[
              const SizedBox(height: 3),
              Text(
                '${(ws.knownRatio * 100).round()}% known · ${ws.fresh} new',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: color ?? c.bg.withValues(alpha: 0.75), shape: BoxShape.circle),
      child: Icon(icon, size: 11, color: color == null ? c.accent : Colors.white),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.stories});
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    final feel = context.feel;
    const w = 124.0;
    final extra = 50 * MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: w * 4 / 3 + extra,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: stories.length,
        separatorBuilder: (_, _) => SizedBox(width: feel.gap),
        itemBuilder: (context, i) => SizedBox(width: w, child: _GridCard(story: stories[i])),
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
    final feel = context.feel;
    final showStats = feel.meta && app.settings.libraryShowStats;
    final ws = showStats ? app.wordStats(story) : null;
    final compact = feel.id == 'compact';
    return Pressable(
      scale: 0.98,
      onTap: () => app.openStory(story),
      onLongPress: () {
        Haptic.medium();
        showStoryActions(context, story);
      },
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 10),
        decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(feel.r(18))),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 40 : 54,
              height: compact ? 54 : 72,
              child: StoryCover(cover: story.cover, title: story.title, imagePath: coverImagePath(app, story), radius: feel.r(10), showTitle: false),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (story.favorite) ...[Icon(PhosphorIconsFill.star, size: 12, color: c.accent), const SizedBox(width: 5)],
                      Flexible(
                        child: Text(
                          story.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: storyDirection(story),
                          textAlign: TextAlign.left,
                          style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 3 : 5),
                  Row(
                    children: [
                      if (!app.scoped) ...[LangBadge(story.language), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(
                          [
                            if (story.finishedAt != null) 'Finished' else '${app.minutesLeft(story)} min left',
                            if (ws != null) '${(ws.knownRatio * 100).round()}% known',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 9),
                  ThinProgress(value: story.progress, height: 3),
                ],
              ),
            ),
            const SizedBox(width: 4),
            RoundBtn(icon: PhosphorIconsBold.dotsThree, label: 'More', onTap: () => showStoryActions(context, story)),
          ],
        ),
      ),
    );
  }
}

/// Minimal rows: the title and a little progress, nothing else.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final done = story.finishedAt != null;
    return Pressable(
      scale: 0.985,
      onTap: () => app.openStory(story),
      onLongPress: () {
        Haptic.medium();
        showStoryActions(context, story);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                story.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: storyDirection(story),
                // Right-to-left titles keep their direction but line up with the rest.
                textAlign: TextAlign.left,
                style: AppTheme.f(17, weight: FontWeight.w700, color: done ? c.textTertiary : c.text),
              ),
            ),
            const SizedBox(width: 12),
            if (story.favorite) ...[Icon(PhosphorIconsFill.star, size: 13, color: c.accent), const SizedBox(width: 8)],
            Text(
              done ? 'Done' : '${(story.progress * 100).round()}%',
              style: AppTheme.d(12.5, weight: FontWeight.w700, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
