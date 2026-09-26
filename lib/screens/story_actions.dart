import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/exporter.dart';
import '../data/io.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';

Future<void> showStoryActions(BuildContext context, Story story) async {
  final app = context.appRead;
  final c = context.sc;
  final action = await pickOption<String>(
    context,
    title: story.title,
    subtitle: '${story.wordCount} words · ${story.paragraphs.length} paragraphs',
    items: [
      const OptionItem('read', 'Read', icon: PhosphorIconsRegular.bookOpenText),
      story.favorite
          ? const OptionItem('fav', 'Remove from favourites', icon: PhosphorIconsFill.star)
          : const OptionItem('fav', 'Add to favourites', icon: PhosphorIconsRegular.star),
      const OptionItem('edit', 'Details, cover and text', icon: PhosphorIconsRegular.pencilSimple),
      const OptionItem('shelves', 'Shelves', icon: PhosphorIconsRegular.bookBookmark),
      story.finishedAt == null
          ? const OptionItem('finish', 'Mark as finished', icon: PhosphorIconsRegular.checkCircle)
          : const OptionItem('reset', 'Read again from the start', icon: PhosphorIconsRegular.arrowCounterClockwise),
      const OptionItem('export', 'Export as JSON', icon: PhosphorIconsRegular.export),
      const OptionItem('delete', 'Delete', icon: PhosphorIconsRegular.trash, danger: true),
    ],
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case 'read':
      app.openStory(story);
    case 'fav':
      app.toggleFavorite(story);
    case 'edit':
      app.go('story:${story.id}');
    case 'shelves':
      await showStoryShelves(context, story);
    case 'finish':
      final n = app.finishStory(story);
      showNotchToast(
        context,
        title: 'Finished',
        subtitle: n > 0 ? '$n new words marked known' : story.title,
        icon: PhosphorIconsFill.checkCircle,
        accent: c.sage,
      );
    case 'reset':
      app.resetProgress(story);
    case 'export':
      await exportStoriesFlow(context, [story]);
    case 'delete':
      // No confirm: the toast offers an undo instead.
      await app.deleteStory(story.id);
      if (app.routeName == 'story' || app.routeName == 'reader') app.go(app.lastTab);
      if (context.mounted) {
        showNotchToast(
          context,
          title: 'Story deleted',
          subtitle: story.title,
          icon: PhosphorIconsFill.trash,
          accent: c.danger,
          action: 'Undo',
          onAction: app.restoreStory,
          duration: const Duration(seconds: 5),
        );
      }
  }
}

Future<void> exportStoriesFlow(BuildContext context, List<Story> stories) async {
  final json = exportStories(stories);
  final name = stories.length == 1 ? '${safeFileName(stories.first.title)}.json' : 'sefer-stories-${stamp()}.json';
  final how = await pickOption<String>(
    context,
    title: 'Export',
    subtitle: 'In the same format Sefer imports',
    items: const [
      OptionItem('save', 'Save to a file', icon: PhosphorIconsRegular.floppyDisk),
      OptionItem('share', 'Share', icon: PhosphorIconsRegular.shareNetwork),
    ],
  );
  if (how == 'save') {
    final ok = await Io.saveText(name, json, mime: 'application/json');
    if (ok && context.mounted) {
      showNotchToast(context, title: 'Saved', subtitle: name, icon: PhosphorIconsFill.floppyDisk);
    }
  } else if (how == 'share') {
    await Io.shareFile(name, json, mime: 'application/json');
  }
}

Future<void> showStoryShelves(BuildContext context, Story story) => showAppSheet<void>(
  context,
  (ctx) => StatefulBuilder(
    builder: (ctx, setState) {
      final app = ctx.app;
      final c = ctx.sc;
      return SheetBody(
        title: 'Shelves',
        subtitle: story.title,
        children: [
          if (app.shelves.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Shelves group stories however you like: a course, a level, a book.',
                textAlign: TextAlign.center,
                style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.4),
              ),
            ),
          if (app.shelves.isNotEmpty)
            ToolGroup(
              color: c.bgRaised2,
              radius: 18,
              children: [
                for (final sh in app.shelves)
                  ToolRow(
                    icon: PhosphorIconsRegular.bookBookmark,
                    label: sh.name,
                    trailing: TinySwitch(
                      value: story.shelves.contains(sh.id),
                      onChanged: (_) => app.toggleShelf(story, sh.id),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          GhostButton(
            label: 'New shelf',
            icon: PhosphorIconsBold.plus,
            onTap: () async {
              final name = await askText(ctx, title: 'New shelf', hint: 'Name', action: 'Create');
              if (name != null && name.isNotEmpty) {
                final sh = app.addShelf(name);
                app.toggleShelf(story, sh.id);
              }
            },
          ),
        ],
      );
    },
  ),
);

/// Create, rename and delete shelves; rename and remove tags.
Future<void> showShelvesSheet(BuildContext context) => showAppSheet<void>(
  context,
  (ctx) {
    final app = ctx.app;
    final c = ctx.sc;
    return SheetBody(
      title: 'Shelves and tags',
      children: [
        const Kicker('Shelves'),
        const SizedBox(height: 10),
        if (app.shelves.isNotEmpty)
          ToolGroup(
            color: c.bgRaised2,
            radius: 18,
            children: [
              for (final sh in app.shelves)
                ToolRow(
                  icon: PhosphorIconsRegular.bookBookmark,
                  label: sh.name,
                  value: '${app.stories.where((s) => s.shelves.contains(sh.id)).length}',
                  onTap: () => _editShelf(ctx, sh),
                ),
            ],
          ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'New shelf',
          icon: PhosphorIconsBold.plus,
          onTap: () async {
            final name = await askText(ctx, title: 'New shelf', hint: 'Name', action: 'Create');
            if (name != null && name.isNotEmpty) app.addShelf(name);
          },
        ),
        if (app.allTags.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Kicker('Tags'),
          const SizedBox(height: 10),
          ToolGroup(
            color: c.bgRaised2,
            radius: 18,
            children: [
              for (final t in app.allTags)
                ToolRow(
                  icon: PhosphorIconsRegular.hash,
                  label: t,
                  value: '${app.stories.where((s) => s.tags.contains(t)).length}',
                  onTap: () async {
                    final to = await askText(ctx, title: 'Rename tag', initial: t, action: 'Rename');
                    if (to != null) app.renameTag(t, to);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rename a tag to an empty name to remove it from every story.',
            textAlign: TextAlign.center,
            style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
          ),
        ],
      ],
    );
  },
);

Future<void> _editShelf(BuildContext context, Shelf sh) async {
  final app = context.appRead;
  final v = await pickOption<String>(
    context,
    title: sh.name,
    items: const [
      OptionItem('rename', 'Rename', icon: PhosphorIconsRegular.pencilSimple),
      OptionItem('delete', 'Delete shelf', icon: PhosphorIconsRegular.trash, danger: true, detail: 'Stories stay in your library'),
    ],
  );
  if (!context.mounted) return;
  if (v == 'rename') {
    final name = await askText(context, title: 'Rename shelf', initial: sh.name, action: 'Rename');
    if (name != null && name.isNotEmpty) app.renameShelf(sh.id, name);
  } else if (v == 'delete') {
    app.deleteShelf(sh.id);
  }
}
