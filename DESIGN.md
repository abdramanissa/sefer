# GymMane Design Language

This document covers how GymMane looks, moves and feels, and why. It is written
from the source code. Every value below comes from `lib/`, so it describes the
app as built, not an idealised spec. If you change the code, update this file.

- **Theme and tokens:** `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`
- **Shared components:** `lib/widgets/ui_kit.dart`, `lib/widgets/glass.dart`, `lib/widgets/dialogs.dart`
- **App frame, navigation and screen transitions:** `lib/app/app_shell.dart`

---

## 1. Character in one paragraph

GymMane is a **quiet, warm, monochrome** gym log. The base is near-black or
warm paper, the text is solid white or ink, and the one warm colour is a
**muted copper**. Copper carries identity: the start button, streak flame,
charts and goal ring. Everything else is made from tone steps of one neutral
ramp. There are no borders for decoration, no gradients for their own sake and
no drop shadows on ordinary cards. Depth comes from **stepped surface tones**,
and in a few chosen places from **frosted glass and blur**. The type is one
rounded family, **Nunito**, set heavy for numbers and titles and medium for
everything else. Motion is soft and physical. Things rise into place, pills
stretch like liquid, digits roll like an odometer, and the phone taps back
through haptics. The app is built to be used **mid-set with sweaty hands**, so
targets are big, the workout screen can lock, and the important actions sit in
the thumb zone.

Guiding principles, inferred from how the code is written:

1. **One accent, used sparingly.** Copper (`accent`) marks "this is the thing
   to do or look at". Primary controls use the high-contrast ink (`ember`), not
   the accent.
2. **Tone, not lines.** Surfaces separate by lightness steps
   (`bg` → `bgRaised` → `bgRaised2`). Hairline borders exist but stay subtle.
3. **Pills and soft rectangles.** Buttons, chips, toggles and search are fully
   rounded. Cards use radii of 14–28 px.
4. **Numbers are heroes.** Stats use weight 800 and are animated (`RollIn`,
   `RollingText`).
5. **Offline, private, honest.** The onboarding promises "Free forever / Fully
   offline / Yours to take". The house style forbids faked statistics.
6. **Respect the body and the platform.** Reduced-motion is honoured
   everywhere, haptics are tuned per action, RTL and 16 languages are
   supported.

---

## 2. Typography

### 2.1 Typeface

A single family, **Nunito** (SIL Open Font License), bundled in
`assets/fonts/` and declared in `pubspec.yaml`:

| Weight | File | Style |
|---|---|---|
| 400 | `Nunito-Regular.ttf` | normal |
| 400 | `Nunito-Italic.ttf` | italic |
| 500 | `Nunito-Medium.ttf` | normal |
| 600 | `Nunito-SemiBold.ttf` | normal |
| 600 | `Nunito-SemiBoldItalic.ttf` | italic |
| 700 | `Nunito-Bold.ttf` | normal |
| 800 | `Nunito-ExtraBold.ttf` | normal |
| 900 | `Nunito-Black.ttf` | normal |

Nunito's rounded terminals match the app's pill-shaped geometry. The heavy
weights give numbers a friendly bulk without looking aggressive. The font is
set as the `ThemeData.fontFamily` and applied to the whole `textTheme`, so even
stock Material widgets render in Nunito.

### 2.2 The three style helpers

`AppTheme` defines three constants, all pointing at Nunito:

```dart
static const String disp  = 'Nunito'; // display
static const String sans  = 'Nunito'; // body
static const String round = 'Nunito'; // UI
```

The three names are kept apart so a role could get its own face later without
touching call sites. Each has a helper with its own **default weight and line
height**:

| Helper | Role | Default weight | Default height | Usage count* |
|---|---|---|---|---|
| `AppTheme.f(size, …)` | **UI text.** Almost everything: titles, labels, buttons, numbers | **700** | **1.15** | ~534 |
| `AppTheme.s(size, …)` | Running/body text, small captions (nav labels, legends) | **400** | **1.35** | ~73 |
| `AppTheme.d(size, …)` | Display/tabular: chart axes, big figures | **700** | **1.0** | ~28 |

\*Counted with `grep` across `lib/`.

`AppTheme.f` is the default. Use `s` for sentences that need more line height,
and `d` where the tight 1.0 line height matters (chart labels, large figures).

### 2.3 Weight usage across the app

| Weight | Occurrences | Meaning |
|---|---|---|
| w900 | 6 | Only for the giant countdown numeral (170 px) and similar one-offs |
| w800 | 83 | Screen titles, hero titles, stat values, selected option, dialog titles |
| w700 | 168 | Section headings, buttons, emphasised values (also `f`'s default) |
| w600 | 205 | Labels, chips, secondary values, kickers |
| w500 | 165 | Subtitles, helper text, descriptions, input text |
| w400 | 2 | Almost never. Body copy uses `s()`, which defaults to 400 |

The hierarchy comes from **weight and colour**, not from many sizes.

### 2.4 Type scale

These sizes recur. Half-point sizes are deliberate: the scale is tuned by eye.

| Size (px) | Weight | Colour | Used for |
|---|---|---|---|
| 170 | 900 | `text` | Start-workout countdown numeral |
| 66 | 700 | `text` | Streak number on share card |
| 44 | 800 | `text` | "GymMane" wordmark on welcome screen |
| 36 | 800 | `text` | Rest-timer clock |
| 34 | 800 | `text` | Number-entry dialog input |
| 30–32 | 800 | `text` | Home hero title (30, h 1.1), onboarding step titles (30, h 1.12), award name (32) |
| 26–28 | 700 | `text` | Exercise name in session (26), session summary title (28) |
| 22–23 | 800 | `text` | `ScreenTitle` default (22), stat values (23) |
| 19–21 | 700–800 | `text` | Section headings (19), dialog titles (19/800), date on Home (21) |
| 17 | 700 | `text` | `SheetTitle` |
| 15.5 | 700 | `onEmber` | `PrimaryButton` label (letter-spacing 0.2) |
| 14.5 | 500–600 | `text` | List-row labels, option rows, preference rows |
| 13–13.5 | 500–700 | `textSecondary` | Body/help text (h 1.45), `GhostButton` label, dialog actions (14) |
| 12–12.5 | 500–600 | `textSecondary` | Subtitles, chips, `SegToggle` |
| 10.5–11.5 | 600–700 | `textTertiary` | **Kickers**: uppercase section labels |
| 9.5–10 | 600–800 | `textTertiary` | Tiny uppercase captions under stats, nav-bar labels (9.5, `s()`) |

### 2.5 Kickers: the uppercase micro-label

A signature of the design. Small **UPPERCASE** labels with wide tracking sit
above headings and stats:

```dart
Text(t.today.toUpperCase(),
  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4));
```

- Size 9.5–12, weight 600–800, colour `textTertiary` (or an accent for a
  highlighted state).
- Letter-spacing **0.9 to 3**: 1.3–1.6 for section labels, 2–3 for timer and
  countdown captions.
- Always `.toUpperCase()` in code. Translators write sentence case, and the
  widget uppercases it.
- The `Kicker` widget in `ui_kit.dart` packages this (default 12 px, w600,
  spacing 3).

### 2.6 Casing rules

`ui_kit.dart` has two helpers that fix accidental ALL-CAPS strings from
translations:

- `titleCase(s)` is applied to buttons, pills, `ScreenTitle` and dialog
  actions. If the string is entirely uppercase, it becomes "First letter +
  lowercase". Short tokens (≤ 4 chars, no space, e.g. "RPE", "PR") and anything
  containing digits are left alone.
- `sentenceCase(s)` is applied to `ToolRow` labels and does the same with
  fewer exceptions.

So: **labels read in sentence case, and only kickers are uppercase.**

### 2.7 Numeric typography

- Digits animate. `RollingText` and `RollIn` (see §8) render each character in
  its own clipped cell.
- **Fixed-width digit cells.** `digitCell()` measures the widest of 0–9 for a
  given style and text scale, then gives every digit that width. Numbers don't
  jitter as they change, which works like tabular figures in a proportional
  font.
- Units sit **after** the value in a smaller, lighter style, aligned on the
  alphabetic baseline (for example `23 / w800` + `kg / 11 / w600 /
  textSecondary`).

---

## 3. Colour

### 3.1 The token system

All colours live in one `ThemeExtension`, **`GymColors`**, reached through
`context.gc`. Screens never read `Theme.of(context).colorScheme` directly. The
extension implements `lerp`, so a theme switch animates every token smoothly.

There are two palettes, **dark** (default: `themePref = 'dark'`) and
**light**, plus a "system" option that follows the platform brightness.

### 3.2 Full palette

| Token | Dark | Light | Role |
|---|---|---|---|
| `pageBg` | `#0A0908` | `#FFFEFD` | Full-bleed page backdrops (award celebration, save card) |
| `bg` | `#0A0A0A` | `#F7F4F0` | Scaffold background: the "floor" |
| `bgRaised` | `#1C1C1C` | `#FFFFFF` | Cards, sheets, dialogs: **level 1** |
| `bgRaised2` | `#2B2B2B` | `#ECE8E3` | Controls inside cards, chips, steppers, tracks: **level 2** |
| `border` | `#3E3E3E` | `#E0DBD5` | Hairlines, dividers, background pattern ink |
| `navBg` | `#0A0A0A` @ 85% | `#FFFEFD` @ 95% | Translucent nav surface |
| `text` | `#FFFFFF` | `#1A1713` | Primary text |
| `textSecondary` | `#9A9A9A` | `#5F574F` | Secondary text, idle icons |
| `textTertiary` | `#666666` | `#8A8179` | Kickers, captions, disabled, inactive nav |
| `ember` | `#FFFFFF` | `#1A1713` | **Primary ink.** Filled buttons, active toggles, selected states |
| `emberDeep` | `#D0D0D0` | `#000000` | Pressed or deeper variant of ember |
| `onEmber` | `#0A0A0A` | `#FFFFFF` | Text/icon on an `ember` fill |
| `emberSoft` | white @ 10% | ink @ 7% | Tinted chip backgrounds (muscle chip, unlock pill) |
| `emberShadow` | black @ 50% | ink @ 12% | Shadow colour |
| `accent` | `#D9A184` | `#9E4E27` | **Copper, the brand colour** |
| `accentSoft` | copper @ 16% | copper @ 12% | Chart fills, hero glow, badge backgrounds |
| `brass` | `#B98F72` | `#8A6B41` | Secondary warm: supersets, "rest-pause", links to plans, FAB gradient end |
| `sage` | `#8FA377` | `#3D7A52` | **Success/done.** Completed sets, rest timer, finished exercises |
| `sageSoft` | sage @ 16% | sage @ 12% | Done-set row fill |
| `mutedFill` | `#2A2A2A` | `#E9E4DE` | Neutral filled areas |
| `heatEmpty` | `#242424` | `#E7E2DC` | Empty heatmap cell |
| `info` | `#7FA8C9` | `#3268A0` | Informational: drop sets, "note" notes |
| `warn` | `#E0B15A` | `#9A6A12` | Warm-up sets, "plan" notes |
| `danger` | `#E5674C` | `#C0392B` | Destructive, failure sets, "pain" notes |

The Material `ColorScheme` is only a bridge for stock widgets:
`primary = accent`, `onPrimary = onEmber`, `surface = bgRaised`,
`onSurface = text`, `error = #E5563B`. Splash and highlight colours are set to
**transparent**. There are no Material ink ripples anywhere. Feedback comes
from scale and haptics instead (§8, §9).

### 3.3 How to read the palette

- **Dark mode is neutral grey; light mode is warm.** The dark greys have no
  hue, while the light greys lean brown (`#F7F4F0`, `#ECE8E3`, `#1A1713`).
  Light mode reads like warm paper and ink, not clinical white.
- **`ember` is the inverse of the background, not orange.** Despite the name,
  `ember` is pure white in dark mode and near-black ink in light mode. It is
  the "maximum contrast" fill used for the primary button, active toggles,
  the selected segment, done weekday dots and the current-exercise progress
  bar. Reach for `accent` when you want copper.
- **Copper is tuned per mode.** `#D9A184` is a soft peach-copper that glows on
  black. `#9E4E27` is a deep burnt sienna with enough contrast on paper.
- **The semantic colours are desaturated and earthy** (sage rather than
  green, a muted steel blue, ochre, brick red). They sit next to copper
  without clashing.
- **"Soft" variants are the base colour at 7–16% alpha.** They tint a
  surface without competing with the text on top.

### 3.4 Where each colour appears (semantic maps)

**Set types** (`widgets/set_kind.dart`). The tag letter is drawn in the colour:

| Kind | Colour | Tag |
|---|---|---|
| Normal | `text` | (none) |
| Warm-up | `warn` | W |
| Drop | `info` | D |
| Failure | `danger` | F |
| Rest-pause | `brass` | RP |

**Journal note kinds** (`widgets/note_kit.dart`): Note → `info`, Plan →
`warn`, Done → `sage`, Pain → `danger`.

**Workout progress strip** (`session_screen.dart`): current exercise →
`ember` (or `sage` if all its sets are done), finished → `sage`, partly done
→ `bgRaised2` mixed 45% toward `sage`, untouched → `bgRaised2`. The current
segment is also taller (6 px vs 4 px).

**Rest timer** uses `sage`. The hold/stopwatch cards and "last time" hints use
neutrals. PR/trend-up uses `sage`, streak/flame uses `accent`.

### 3.5 Secondary palettes (outside the token system)

These palettes are deliberately *not* theme tokens. Each belongs to one
feature.

**Heatmap/body-map ramps** (`widgets/body_map.dart`), four levels each. The
user picks a tone from the Progress screen. Dark ramps go dark → bright, and
light ramps go light → dark, so "more" always means "more contrast".

| Tone | Dark ramp | Light ramp |
|---|---|---|
| ember (default) | `#7A4028 #B4632C #E38B3A #FFC168` | `#D9B48A #C07A3C #9E4A24 #6E2A16` |
| green | `#1B4B2C #2C7A44 #3FA95C #63D67F` | `#BBD9BE #7FB88A #488C58 #255E32` |
| blue | `#1E3A5C #2C5E96 #3D86C9 #6EB4F0` | `#BACFE8 #7EA5D2 #3F74AE #1F4876` |
| mono | `#3A3A3A #5E5E5E #8C8C8C #D8D8D8` | `#CFC8BC #9C958A #6B655C #3A352F` |

An idle muscle is `bgRaised2` mixed 32% toward `textSecondary`.

**Routine folder hues** (`widgets/routine_folder.dart`) are six pastels:
peach `#F3C7B1`, lavender `#A78BDA`, sage `#A8C99E`, sky `#9CC2E8`, sand
`#E8CF98`, rose `#E6A4B9`. Each routine gets a hue from its stored `color`
index, or from a hash of its id. The hue is then **adapted per mode**: back
flap = hue darkened 42% (dark) or 18% (light), front = `bgRaised2` tinted 14%
(dark) or 30% (light), ink = hue darkened 35%.

**Sticky-note paper** in the Journal folder preview: yellow `#F2D680`, peach
`#F3C7B1`, sage `#A8C99E`. In dark mode these are dimmed 8% toward black.

**Medal metals** (`catalog/medal_look.dart`). The medal shader uses five
colours per metal (base, lip, plate top, plate low, ink):

| Metal | Base | Lip | Plate top | Plate low | Ink |
|---|---|---|---|---|---|
| Bronze | `#A96A38` | `#E3A878` | `#F1B585` | `#AB6635` | `#40251A` |
| Silver | `#A3ABB6` | `#E2E9F0` | `#F7FAFD` | `#A9B4C1` | `#272E37` |
| Gold | `#C6982C` | `#F6D97B` | `#F8E296` | `#BF8F1C` | `#43300C` |
| Diamond | `#B2C9DC` | `#EAF5FD` | `#FFFFFF` | `#C1D6E6` | `#1F3646` |

Gems for the top tier: ruby `#C02347`, sapphire `#2F63C4`, emerald `#1F9F74`.
Tiers follow difficulty: first steps are bronze, 7-day streaks and 10 workouts
are silver, 30-day streaks and 100 workouts are gold, and 100-day streaks,
100 tonnes and 365 workouts are diamond with a gem.

**Celebration confetti** (`award_celebration.dart`) is the only place with
saturated "party" colours: `#FF4D6D #4CC3FF #57D68D #FFC93C #B06CFF #FF8A3D
#F4F6FA`. Workout-complete confetti uses theme colours instead:
`accent, brass, sage, text`.

**Profile badge colours**: gold `#E8B84B`, blue `#4A9EEB`, green `#54B979`.

**Sticker text swatches**: white, `#111111`, `accent`, `brass`, `sage`, bone
`#E8E1D7`.

**Notch toast** is always black: body `#000000` into a `#0B0B0B` pill, white
title, 60% white subtitle. The icon and action take a per-toast accent, which
defaults to sage `#8FA377`. It imitates a hardware "dynamic island", so it
ignores the theme.

**App icon**: adaptive background `#0C0B0A`, a near-black matching `pageBg`.

### 3.6 Backgrounds

The screen behind all content (`widgets/app_background.dart`) is user
configurable (`bgPattern`):

- **none**: flat `bg`.
- **dots** (default): 1.1 px dots on a **26 px grid**, `border` at 50% alpha.
- **grid**: 1 px lines on the same 26 px grid, `border` at 35% alpha.
- **photo**: a user photo, `BoxFit.cover`, under a vertical scrim from
  `bg @ dim` to `bg @ dim + 0.18`. `dim` defaults to 0.55 and is clamped to
  0.30–0.85, so text stays readable.

The pattern is painted once in a `RepaintBoundary` and ignores pointer input.
It suggests graph paper or a training log, and it gives the glass nav bar
something to blur.

---

## 4. Shape, size and spacing

### 4.1 Corner radii

Most-used radii, from a code-wide count:

| Radius | Count | Used for |
|---|---|---|
| **100** (full pill) | 36 | Buttons, chips, search field, segmented toggle, switches, streak pill |
| **28** | 37 | Bottom sheets (top corners), nav bar, glass surfaces |
| **26** | 9 | Home hero card, dialogs, timer panel |
| **22 / 24** | 29 | Home content cards, session summary |
| **20** | 22 | `SoftCard` default, `ToolGroup`, set table card, exercise art |
| **18 / 16** | 32 | Option groups, recommended cards, small panels |
| **14 / 12** | 42 | Set rows, list tiles inside cards, thumbnails |
| **8** | 3 | Stepper buttons, RPE cells |
| **2–3** | 21 | Heatmap cells, progress-strip segments, tick marks, handles |

Rules of thumb: **interactive = pill**, **container = 20–28**, **nested
inside a container = 12–16**, **data marks = 2–3**. Radii shrink as elements
nest.

### 4.2 Component sizes

| Element | Size |
|---|---|
| `PrimaryButton` | full width × **56** (52 in Home hero), pill |
| `GhostButton` | height **46**, pill, `bgRaised2` |
| `SearchField` | height **48**, pill |
| `RoundAction` / `RoundBtn` | **36** circle, 16 px icon |
| Option row | min height **50** |
| `ToolRow` / preference row | min height **56** / **52** |
| Set "done" checkbox | **28** visual circle inside a **44 × 44** hit target |
| RPE cell | 30 tall inside a 44 tall target |
| `TinySwitch` | **44 × 26**, 20 px knob, 3 px inset |
| `StepperControl` button | **30** square, radius 8 |
| Sheet handle | **40 × 4**, radius 2 |
| Nav bar | height **74**, floats 18 px from the sides and bottom |
| Nav item slot | **58** wide, 22 px icon, 9.5 px label |
| Centre FAB | **54** circle |
| Weekday dot (Home) | **32** circle |
| Goal ring | **44** diameter, 4 px stroke |

Touch targets are 44 px or larger even when the visible mark is smaller. The
set checkbox and RPE cell both use this pattern.

### 4.3 Spacing

There is no formal 4/8 grid token. In practice:

- **Page gutters: 20 px** left and right (`EdgeInsets.fromLTRB(20, 14, 20, 116)`
  on Home). The 116 px bottom padding clears the floating nav bar.
- **Card padding: 18–22 px** (`SoftCard` default 20).
- **Sheet padding: 20 px sides, 12 top, 28 + safe area bottom** (`sheetPad()`).
- **Vertical rhythm on Home:** 14 px between related cards, **30 px** before
  a new section heading, 14 px from heading to its content.
- **Row internals:** 16 px horizontal padding. Icon-to-label gap is 12–14 px.
  Dividers are inset 16 px on both sides.
- **Horizontal carousels:** 12 px gaps (Home recommended), 10 px between the
  folder tiles.

---

## 5. Surfaces, depth and material

### 5.1 The elevation model

GymMane uses **tone steps instead of shadows**:

```
bg (floor)  →  bgRaised (card / sheet / dialog)  →  bgRaised2 (control inside card)
```

`SoftCard` is the basic container: `bgRaised` fill, 1 px `border` stroke,
radius 20, padding 20. Many cards pass `borderColor: Colors.transparent`
(`ToolRow`, `ToolGroup`), so the tone step alone separates them. Grouped lists
(`OptionGroup`, `ToolGroup`) clip to a rounded rectangle and separate rows with
**1 px inset dividers**. This follows the iOS settings pattern, with rounded
groups instead of full-bleed tables.

**Shadows are rare and meaningful.** They appear only on things that float
above the page:

- Nav bar: `#000000 @ 30%`, blur 32, y + 12.
- Centre FAB: `accent @ 45%`, blur 18, y + 6. A copper glow.
- Liquid selection pill while dragged: black @ 28%, blur 22, y + 8.
- Folder front flaps and sticky notes: soft black 12–50% to sell the paper
  metaphor.

### 5.2 Glass

`GlassSurface` (`widgets/glass.dart`) is the frosted material:

1. `BackdropFilter` blur, sigma **22** by default (16 on the nav bar).
2. Tint `bgRaised` at **66%** alpha in dark mode or **74%** in light mode.
3. A top-lit sheen: a vertical white gradient from 7% (dark) / 30% (light) at
   the top to 0 at 60% height.
4. A **0.8 px white rim** at 8% (dark) / 50% (light) alpha.

It is used for the floating nav bar. Everything inside the shell sits in one
`BackdropGroup`, so the blurs share a backdrop capture.

### 5.3 Blurred modal barriers

Every sheet and dialog opens through `showAppSheet` or `showAppDialog`, never
the raw Material functions. Their barrier:

- Scrim `black @ 32%` (sheets) or `36%` (dialogs).
- Plus a **backdrop blur that ramps up with the route animation** to
  `kSheetBlur = 14` (eased with `easeOut`, skipped under 0.3 so it costs
  nothing when closed).

The page behind a sheet goes soft and dim, like looking past a card held up
close.

### 5.4 Edge blur

`EdgeBlur` fades content into the screen edges instead of cutting it off hard:

- **Top:** appears (220 ms fade) when a scrollable page is scrolled more than
  6 px. It covers status-bar height + 64 px. It is enabled only on the routes
  in `_blurTop` (home, progress, session, about, awards, measures, routines,
  tools, etc.).
- **Bottom:** always present behind the nav bar, 128 px + safe area.
- **Implementation:** on devices that support shader image filters, two
  stacked layers each combine a Gaussian blur (sigma × 0.35 and sigma × 1)
  with the `edge_fade.frag` shader. The shader multiplies alpha by a
  `smoothstep` over distance from the edge, which produces a *progressive*
  blur. Other devices fall back to 6 stacked strips of decreasing blur. Both
  paths add a colour fade over them: `bg` at alpha
  `0.82 → 0.62 → 0.38 → 0.17 → 0.05 → 0`.

### 5.5 System chrome

Status and navigation bars are **fully transparent** with contrast
enforcement off. Icon brightness follows the theme (`_overlayDark` and
`_overlayLight` in `app_shell.dart`). The app draws edge to edge, and the
blurs above handle legibility.

---

## 6. Iconography

### 6.1 Phosphor Icons, three weights

The icon set is **Phosphor** (`phosphoricons_flutter`), used in three weights
with distinct jobs:

| Weight | Count | Job |
|---|---|---|
| `PhosphorIconsRegular` | ~254 | Default: row icons, idle nav items, inline affordances |
| `PhosphorIconsFill` | ~78 | **Selected or active** state (nav items when selected), medals, toasts, status |
| `PhosphorIconsBold` | ~46 | Small chevrons/carets (`caretRight` at 14 px), toast arrows, check marks |

The **regular → fill swap on selection** is the core icon interaction. The nav
bar also cross-fades the colour from `textTertiary` to `text` over 300 ms.

Standard sizes: 22 (nav), 19 (list-row leading icon inside a 22 px column),
16–18 (buttons, toasts), 14–15 (chevrons, inline), 11–12 (chip icons).

### 6.2 Custom stroke icons (`Ic`)

`widgets/svg_icon.dart` defines a small hand-drawn set as SVG path strings on
a 24-unit viewBox. They are rendered by `SvgPathIcon` with **round caps and
round joins**, and stroke widths of 1.8–3. Glyphs: flame, play, barbell,
wrench, checkBold, close, chevrons, search, star, trendUp, house, bars, gear,
layers, clock, noAds, plus, and more. Paths are parsed once and cached.

Use `Ic` for the few glyphs that need a precise brand shape: the streak flame
(always `accent`), the play triangle in the start button, the bold check in
done states and the back chevron. Use Phosphor for everything else.

### 6.3 Illustration

- **Exercise art** (`assets/art/*.txt`): each exercise is 2–3 animation
  frames. Every frame is one SVG path on one line, originally from Workout
  Guide / Everkinetic (CC BY-SA 4.0). The paths are **tinted with `text`**, so
  the art is a single-colour silhouette that follows the theme. It is drawn on
  a `bgRaised2` tile with a `border` stroke, with 7% padding. When `live`,
  the frames loop on a 1560 ms cycle. Each frame holds for 72% of its step and
  then cross-fades (`easeInOut`) to the next, ping-ponging through the
  frames. The result is a calm "flip book" demo rather than video. While art
  loads, a `Shimmer` placeholder shows. If loading fails, a Phosphor barbell
  in `textTertiary` is used.
- **Runner** (`assets/img/runner.png`) appears on the welcome screen (90%
  opacity) and behind the Home hero (60% opacity, right-aligned).
- **Body map and muscle radar** are SVG muscle paths filled with the heat
  ramps (§3.5).
- **Medals** (§7.8) are real-time ray-marched 3D objects.

---

## 7. Components

All in `lib/widgets/ui_kit.dart` unless noted.

### 7.1 Buttons

| Component | Look | Press behaviour |
|---|---|---|
| **`PrimaryButton`** | Full width, 56 tall, pill, **`ember` fill** (white on dark, ink on light), `onEmber` label 15.5/700, optional 15 px `Ic` icon with a 9 px gap. The label scales down to fit (never wraps). | `Pressable`, scale 0.965 |
| **`GhostButton`** | 46 tall, pill, `bgRaised2` fill, `ember` icon 16 px + `text` label 13.5/700 | scale 0.965 |
| **`Pill`** | Custom bg/fg, pill, 14 × 8 padding, 13/600 | scale 0.94 |
| **`RoundAction` / `RoundBtn`** | 36 circle, `bgRaised` + `border` (or filled `ember`) | scale 0.9 |
| **Dialog action** | Text button, pill-shaped hit area, 14/700 in `accent` (or `danger`). Cancel is 14/600 in `textSecondary`. | – |
| **Centre FAB** | 54 circle, **diagonal gradient `accent → brass`**, copper glow shadow, filled play icon in `bg` colour | – |

The primary action is ink-coloured, not copper, on purpose. Copper appears on
the FAB, the one button that is always there, so the brand colour marks
"start training".

### 7.2 Selection controls

- **`TinySwitch`** is 44 × 26. On: `ember` track, `onEmber` knob. Off:
  `bgRaised2` track, `border` rim, `textTertiary` knob. The knob slides over
  140 ms.
- **`SegToggle`** is a pill track in `bgRaised2` with 3 px padding. The
  selected segment is an `ember` pill with `onEmber` 12/600 text, and the
  others are `textSecondary`. Used for kg/lb, chart ranges, etc.
- **`StepperControl`** is `–` / value / `+`. The buttons are 30 px `bgRaised2`
  squares with radius 8. The value is a `RollingText` at 16/700 and can be
  tapped to type an exact number (`askNumber`).
- **`OptionGroup` + `OptionItem`** is the standard picker inside sheets. It is
  a rounded (18) `bgRaised2` group with inset dividers and rows at least 50
  tall. The selected row has an `ember` icon, `ember` 14.5/800 label and a
  filled check-circle on the trailing edge. Danger rows are `danger`. An
  optional detail line is 12/500 `textSecondary`.

### 7.3 Inputs

- **`SearchField`** is a 48 tall pill in `bgRaised`, with a 16 px `Ic.search`
  icon, 14/500 text and a copper cursor. A clear button (a 20 px `bgRaised2`
  circle with a 10 px ×) appears only when there is text.
- **Number dialog** (`askNumber`) is a centred 34/800 input on a `bgRaised2`
  field (radius 18, no border), autofocused with all text selected. It accepts
  either `,` or `.` as the decimal separator.
- The cursor colour is always `accent`.

### 7.4 Headers and titles

- **`ScreenHeader`** is a 36 px back `RoundBtn`, a 12 px gap, then
  `ScreenTitle` (20–22 / **800**, one line, ellipsis) with an optional 12.5/500
  subtitle, then trailing actions.
- **Home top bar**: kicker "TODAY" over the long date (21/700) on the left.
  On the right is a streak pill: `bgRaised` capsule, copper flame and the
  count in 14/800.
- **Section heading**: 19/700 title and, when it links somewhere, a 14 px bold
  caret in `textTertiary` pushed to the far edge. The whole row is tappable.

### 7.5 Sheets and dialogs

- **Bottom sheet anatomy**: `bgRaised` container with **28** px top radius,
  `sheetPad` padding, `SheetHandle` (40 × 4 in `bgRaised2`), 16–20 px gap,
  `SheetTitle` (17/700, centred, optional 12/500 subtitle), content, and
  usually a `PrimaryButton` at the bottom.
- **Dialogs** (`appDialog`) are `bgRaised`, radius **26**, 28 px side inset
  and 24 px inner padding. Title 19/800, body 13.5/500 `textSecondary` at
  line height 1.45, actions right-aligned. They enter with a **scale from 0.92
  plus a fade** on `easeOutBack` (a slight overshoot) and exit on
  `easeInCubic`.
- `askConfirm` is the one confirm pattern: a neutral cancel plus an `accent`
  confirm, or `danger` when the action is destructive.

### 7.6 Notch toast (the "dynamic island")

`showNotchToast` in `widgets/liquid_notch.dart` is the app's feedback channel.
There are no Material snackbars.

- It **grows out of the device's camera cutout.** The source rect comes from
  the display cutout. If there is none, it falls back to a 126 × 37 pill at
  the top centre.
- A black blob **drips down** from the cutout, necks, detaches and swells into
  a 307 × 53 pill (scaled to screen width / 390). The shape follows 13 enter
  keyframes over 650 ms and 10 exit keyframes over 450 ms. The shape is
  painted as a union of the cutout, a cubic "bridge" neck and the pill, with a
  black-to-`#0B0B0B` gradient, so it looks like one liquid body.
- Content fades in with a small blur (sigma up to 3) that clears as opacity
  reaches 1.
- **Layout**: 35 px icon well with an accent-coloured icon, title 14/800
  white, subtitle 11.5/600 white @ 60%, optional action in 13/800 accent.
- **Duration scales with reading length**:
  `max(2200 ms, 900 + 330 ms × word count)`.
- Toasts queue per overlay. Interrupting one blends from the current frame, so
  there are no jumps. With reduced motion it appears in its final state.
- It is a live region, so screen readers announce it.

Used for: rest over (sage), auto-advance to the next exercise (ember, or brass
in a superset), set deleted with undo (danger), screen locked hint (accent)
and "all sets done" (sage).

### 7.7 Data visualisation (`widgets/charts.dart`)

- **Line charts** (`VolumeChart`, `TrendChart`, `Sparkline`): copper `accent`
  stroke, **3 px** (2.5 for spark/trend), round caps and joins. The area fill
  is `accentSoft`. The **last point is a ring**: a `bgRaised` dot with a 3 px
  accent outline, radius 4–5. Grid lines are 1 px `border` at 0, 50% and 100%.
  Axis labels are `AppTheme.d(10, w600, textTertiary)`.
- **Heatmap**: 12 columns, 4 px gaps, square cells with radius 3. Empty cells
  are `heatEmpty` and filled cells use the chosen ramp. Tapping a day opens its
  sheet.
- **Goal ring**: 4 px stroke, `bgRaised2` track and `accent` progress.
- **Split bars**: 6 px radius-3 `LinearProgressIndicator` in `accent` on
  `bgRaised2`.
- **Rest timer ticks** (`timer_panel.dart`): a row of 3 px wide bars with
  5.5 px gaps. Lit ticks are 22 px tall in `sage`. Drained ticks drop to 14 px
  and turn `bgRaised2` over 380 ms, like an old VU meter emptying.

### 7.8 Medals

`widgets/medal.dart` + `assets/shaders/medal.frag`:

- Static medals (shelves, grids) are pre-rendered **WebP** images in
  `assets/badges/`, with an `_off` variant for locked awards.
- The hero medal (`MedalSpin`) is **ray-marched in real time**. It is a signed
  distance field of a hexagonal (or round) coin built from three stacked
  slabs: body, step and plate. The award's Phosphor icon is embossed on the
  plate, and the back is engraved with the user's handle, the award name and
  the date.
- The **lighting is a virtual photo studio**: a soft sky gradient plus three
  elongated light banks that sway slowly (`sin(t × 0.45)`). A metal BRDF mixes
  sharp and wide reflections by roughness, and Fresnel edges add rim light.
  Top-tier medals have a **faceted gem ring** (30 alternating facets, roughness
  0.05). Output is Reinhard-style tonemapped, gamma 2.2, with ±0.5/255 dither.
- **Locked** medals switch to a matte, desaturated shade (45% grey mix, 40%
  brightness).
- **Physics**: the user can flick the medal to spin it. Yaw velocity decays
  with a 1.9 s time constant, then a spring settles it to the nearest face.
  Tilt springs back to a resting angle. The award reveal spins it in from
  −2π at 13 rad/s.

### 7.9 Folders (Home and Routines)

A tactile, skeuomorphic touch in an otherwise flat UI:

- **`HomeFolder`** is a manila-folder shape (tab on the back flap, custom
  bezier path, 16 px corners). A "peek" of the contents sits between the back
  and front flaps: fanned routine cards, tool cards or sticky notes. The front
  flap carries the title (15.5/800) and a detail line (11/600). Dark mode adds
  a faint white top-lit gradient and a white 8% edge.
- **`RoutineFolder`** is a 196 px tall folder in the routine's pastel hue
  (§3.5), `Pressable` at 0.975.

### 7.10 Loading

`Shimmer` is a diagonal gradient `bgRaised2 → (bgRaised2 mixed 7% to text) →
bgRaised2` that sweeps once over 1300 ms (`easeInOutSine`). It is used where
content is being fetched (exercise art). It plays once rather than looping
forever, to avoid a busy UI.

---

## 8. Motion

Motion is **soft, physical and brief**. Almost every curve is `easeOutCubic`
on the way in and `easeInCubic` on the way out. `easeOutBack` (overshoot) is
reserved for things that "pop": press release, dialog entry and the countdown
numeral.

### 8.1 Duration scale

| Duration | Used for |
|---|---|
| 90 ms | Press-down scale |
| 140 ms | Switch knob |
| 200–240 ms | Small state changes (weekday dot fill, RPE cell, lock opacity, size changes) |
| 260 ms | Press release (`easeOutBack`), liquid pill lift |
| 300 ms | Nav icon/label colour cross-fade |
| 320–340 ms | Progress strip, `AnimatedSize` blocks, onboarding page change |
| 380 ms | **Screen-to-screen transition**, timer tick drain |
| 420 ms | `RollingText` digit roll |
| 460 ms | Liquid nav pill travel |
| 520 ms | Exercise-to-exercise slide in a workout |
| 560 ms (+ stagger) | `Rise` entrance |
| 650 / 450 ms | Notch toast enter / exit, hold-to-unlock fill |
| 1150 ms | `RollIn` count-up of home stats |
| 1300 ms | Shimmer sweep |
| 1560 ms | Exercise art loop |
| 3400 / 5200 ms | Confetti / award celebration |

### 8.2 Press feedback: `Pressable`

Every tappable card and button wraps its child in `Pressable`: **scale down
to 0.965** (buttons), 0.94 (pills), 0.9 (round icons) or 0.975 (large
folders) over **90 ms `easeOut`**, then spring back over **260 ms
`easeOutBack`**. With ripples disabled app-wide, this squish is the main tap
feedback.

### 8.3 Entrance: `Rise` and `RiseScope`

Screen content **rises in a stagger** on first view:

- Each child fades from 0 → 1, moves up from **+22 px**, and scales from
  **0.97 → 1**. The motion takes 560 ms `easeOutCubic` after a delay of
  `40 + index × 70 ms`. The index is capped at 7, so long lists never wait
  more than ~530 ms.
- `riseAll(children)` applies this to a column automatically and skips plain
  spacer `SizedBox`es.
- **`RiseScope` plays it only once per screen per day.** The last play date is
  stored per screen id, so it greets the first visit of the day but doesn't
  nag on every tab switch.
- Skipped entirely when the OS asks to reduce motion.

### 8.4 Screen transitions

The shell (`_animatedScreen` in `app_shell.dart`) uses one custom
`AnimatedSwitcher` for all routes, over **380 ms**. The incoming screen uses
`Interval(0.3, 1, easeOutCubic)` and the outgoing screen uses
`Interval(0.7, 1, easeInCubic)`, so the old screen leaves late and the new one
arrives late. The two overlap briefly in the middle.

- **Tab to tab** (routes in the nav bar) moves **sideways**. The incoming
  screen slides 26 px from the side of travel and the outgoing one 18 px the
  other way.
- **Drilling in or out** moves **vertically**. Incoming moves 22 px up
  (forward) or down (back), outgoing 8 px.
- Both **blur** (up to sigma 10 at the start, decal tile mode), **fade** and
  **scale**: incoming from 1.03 → 1, outgoing 1 → 0.96.

The effect is a depth-of-field "rack focus". The old page drifts back and out
of focus while the new one comes into focus.

### 8.5 The liquid nav pill

The selection indicator behind nav icons (`_LiquidPill`) behaves like a
droplet:

- On change, the **leading edge moves with `easeOutCubic` and the trailing
  edge with `easeInOutCubic`**, so the pill **stretches** toward its target
  and then catches up (460 ms).
- Mid-travel it **squashes vertically** by up to 14%.
- **Drag or long-press to scrub**: pressing on the bar "lifts" the pill. It
  grows 6 px each side, its alpha rises 2.4×, and it gains a white 16% rim, a
  top highlight and a drop shadow, on a springy `Cubic(0.3, 1.25, 0.5, 1)`
  curve. The pill then follows the finger. Each slot crossed fires a
  selection haptic, and the lifted icon scales to 1.06. Releasing navigates.
  The FAB zone is excluded from drag starts.

### 8.6 Numbers that roll

- **`RollingText`**: when a value changes, each character slides vertically
  within a clipped cell. It rolls up when the number increases and down when
  it decreases (a countdown can force the direction). 420 ms per character,
  plus `AnimatedSize` (240 ms) if the width changes. Changes that arrive
  within 180 ms of each other (fast stepper taps) **snap without animation**,
  so rapid input never lags behind.
- **`RollIn`**: on first appearance, a number **counts up from 0 like an
  odometer**. Each digit wheel turns according to its place value, and
  higher places fade in as they become significant. It runs for 1150 ms
  `easeOutCubic`, then hands over to `RollingText`. It only runs when the
  string contains a non-zero digit and obeys `RiseScope` (once per day).

### 8.7 In-workout motion

- **Exercise change**: the exercise header and set card slide **50% of their
  width** in the direction of travel, with a fade and a scale from 0.94, over
  520 ms. A selection haptic fires, and an auto-advance also shows a notch
  toast.
- The rest card, hold card and set rows appear and disappear with
  `AnimatedSize` (320 ms), so the layout breathes instead of jumping.
- A **done set** tints its row `sageSoft`, and the checkbox fills solid `sage`
  with a white bold check.
- **Swipe a set right-to-left to delete.** A `danger @ 16%` background with a
  trash icon is revealed, followed by a danger-tinted undo toast (3200 ms).

### 8.8 Start countdown

When a workout starts (if enabled), a veil of `bg @ 72%` fades in over
280 ms. A **170 px, weight-900 numeral** pops in on `easeOutBack` over the
first 45% of each second, holds, then fades on `easeIn` over the last 30%.
The caption above is 13/800 with 3 px tracking. Each tick is a medium haptic,
and "go" is a heavy one.

### 8.9 Celebrations

- **Workout complete**: theme-coloured confetti burst plus a haptic triplet:
  heavy, then light at 110 ms and light at 220 ms.
- **Award earned**: after a 4 s grace period (6 s between consecutive awards,
  and never during a workout), the page fades to `pageBg @ 95%`. The 3D medal
  spins in and scales from 0.74 → 1 in a stagger, then the award name
  (32/800) and description appear, with party-colour confetti. A shareable
  "save card" with a signature line is available.

### 8.10 Reduced motion

Every custom animation checks `MediaQuery.disableAnimations`: `Rise`,
`RollIn`, `RollingText`, `LiquidNotch`, `EdgeBlur` fades and toasts. When it
is set, they jump to their end state. Treat this as a hard rule for new
motion.

---

## 9. Haptics

Haptics are part of the language, not decoration. There are about 50 call
sites, graded by importance:

| Feedback | Used for |
|---|---|
| `selectionClick` | Scrubbing across nav slots, exercise change, stepper nudges (±15 s), picker ticks, hold-to-unlock start |
| `lightImpact` | Tapping the rest timer, secondary confetti beats, award "saved" confirmation |
| `mediumImpact` | Long-press on a set (open set-type sheet), set deleted, hold-to-unlock completes, back pressed while locked, countdown ticks, award reveal |
| `heavyImpact` | Countdown "go", workout-complete burst, locked-screen hint |

**Selection** means "you moved". **Light** means "noted". **Medium** means
"something changed". **Heavy** means "big moment".

---

## 10. Navigation and information architecture

### 10.1 Shell

The app is a single `AppShell` stack, drawn back to front:

1. `bg` fill
2. `AppBackground` (dots, grid, photo or none)
3. The current screen (in the route switcher)
4. Top `EdgeBlur` (appears on scroll)
5. Bottom `EdgeBlur` (behind the nav)
6. The **floating glass nav bar**
7. Overlays: start countdown, award celebration

Routing is a string (`fit.route`) held in app state rather than a Navigator
stack. That is what allows the custom tab-vs-depth transition logic.
Android back is intercepted. During a locked workout it is blocked with a
haptic. During an unlocked workout it asks to discard. Otherwise it walks
back through app state.

### 10.2 Floating nav bar

- A glass capsule (radius 28, blur 16), **inset 18 px** from the screen edges
  and floating above the bottom safe area. It is not docked to the edge.
- **Four destinations plus a centre action**: Home · Progress · **[▶︎]** ·
  Exercises · Profile. Layout is always LTR, even in RTL locales, so the play
  button stays in the middle and muscle memory holds.
- Items are a 22 px icon over a 9.5/600 label. Inactive items are
  `textTertiary` regular icons. The active item is `text` with a filled icon
  and the liquid pill (`text @ 10%` dark / `7%` light) behind it.
- **The centre play FAB**: a tap starts **today's planned routine** directly
  if one exists, otherwise it opens the start sheet. A long-press always opens
  the start sheet. One tap gets you training.
- Hidden when the keyboard is up (inset > 60 px) and on full-screen routes
  (`fit.showNav`).

### 10.3 Route map

```
Onboarding (until done)
Home ─┬─ Routines ─ Routine edit
      ├─ Tools ─ Tool detail
      ├─ Journal (Notes) ─ Note edit
      └─ day sheet / weekly goal sheet
Progress ─┬─ Measures, Timeline, Compare, Moments (progress photos), Places
Exercises ─ Exercise detail
Profile (settings) ─┬─ Preferences, Awards, About, AI plan
Session (full screen, no nav) ← started from FAB, hero, routine
```

### 10.4 Home screen anatomy (top to bottom)

1. **Top bar**: "TODAY" kicker + long date, streak pill.
2. **Hero card** (radius 26): two large flat translucent circles
   (`accentSoft` 176 px at the left edge, `emberSoft` 92 px at the top)
   for a warm glow, the runner illustration
   at 60% on the right, then the kicker "TODAY'S ROUTINE" or "TODAY'S FOCUS",
   a 30/800 title, a subtitle, and a **Start workout** primary button.
3. **Week strip**: 7 × 32 px circles. Done days are filled `ember` with a
   check. Today has a 2 px `ember` ring. Future days are at 50% opacity. Tap a
   past day to check in or view it.
4. Optional **photo nudge** card when a progress photo is due.
5. **This week**: volume, sets, PRs (rolling numbers) and the weekly goal
   ring, which opens a stepper sheet.
6. **Activity**: heatmap card.
7. **Recommended**: horizontal carousel of 132 px exercise cards with
   animated art.
8. **Folders row**: Routines · Tools · Journal.

### 10.5 Session (workout) screen

This is the most important screen, designed for use **between sets, often
without looking closely**:

- The **progress strip** at the top shows one segment per exercise, coloured
  as in §3.4. Tapping it opens an overview.
- The **exercise header** has the name in 26/700, a muscle chip (`emberSoft`
  pill with `ember` text), a "LAST ..." line from history, and the next target.
  A superset shows a brass "link" chip.
- The **demo** (large 170 px, small 104 px, or off) is chosen in settings.
- The **rest card** is a `TimerPanel`: a tab-shaped label on top, ±15 s pill
  nudges at the sides, a tick meter, a 36/800 countdown, and elapsed/sets
  stats. It uses sage throughout.
- The **set table** has columns for set number/type badge, reps and weight (or
  a time/distance mode), optional RPE/RIR, and a 44 px done checkbox.
  Long-press a row to change its set type. Swipe to delete.
- **"Add set" / "Add warm-up" actions** are quiet text buttons (13/600,
  `textSecondary`, tracking 0.4) side by side under the table, so they don't
  compete with the done checkboxes.
- **Bottom controls**: previous/next circle buttons around the main action,
  then small text actions ("Drop exercise | Finish").
- **Screen lock**: the workout can be locked so pocket or sweaty touches do
  nothing. Locked regions fade to **35% opacity** and ignore input. Two quick
  taps on a locked area show the "screen locked" toast. To unlock, **hold** the
  fingerprint pill for 650 ms while a circular progress ring fills around the
  icon. The pill shrinks 4% while held, and a medium haptic confirms.

### 10.6 Onboarding

This is a `PageView` of steps: welcome → name → body → goal → units → place.

- **Welcome**: the runner illustration, the kicker, the **"GymMane" wordmark
  at 44/800**, a 14.5/500 blurb at line height 1.5, and a grouped card of
  three promises (gift, wifi-slash, export icons): *Free forever, Fully
  offline, Yours to take*.
- Each step uses a 30/800 title (line height 1.12), grouped rows and large
  choice tiles (the units step shows "kg" / "lb" at 30/800, turning `ember`
  when chosen). Elements use `Rise` staggers. Pages move with a 340 ms
  `easeOutCubic` slide.

### 10.7 Settings pattern

Grouped cards under uppercase section labels (10.5/700, tracking 1.3,
`textTertiary`): *Preferences, Home widgets, Data, Support*. Every row is 52
tall: a 19 px regular icon in a 22 px column, a 14.5/500 label, and on the
right either a `TinySwitch`, a `SegToggle`, a `StepperControl`, or the current
value (13/600 `textSecondary`) with a caret that opens an `OptionGroup` sheet.
Choice sheets can end with a centred 11.5/500 hint.

Appearance-related preferences:

- **Theme**: Auto (circle-half icon) / Dark (moon) / Light (sun). **The
  default is Dark.**
- **Demo size**: Large / Small / Off.
- **Background**: None / Dots / Grid / Photo (+ dim slider).
- **Heat tone**: Ember / Green / Blue / Mono (on Progress).

---

## 11. Content and voice

- **All visible text is translated.** It goes through `t.<key>` and ARB files,
  in 16 languages including RTL Arabic and CJK. A test enforces this, and
  literals in widgets are not allowed. The only hard-coded visible string is
  the wordmark "GymMane".
- Copy is **short, direct and friendly**, second person ("Keep training",
  "Discard"). Confirm dialogs name the action on the button, not "OK".
- Dates use the locale's long format. Numbers use the locale's decimals. Units
  are `kg` or `lb`, shown small after the value.
- Designs must survive long translations. Titles use one line with an
  ellipsis, button labels scale down (`FittedBox`), and nav labels scale down.

---

## 12. Accessibility

- Custom controls declare `Semantics`: the nav bar, set checkboxes
  (`checked`, "Mark set N"), RPE cells (value), hold-to-unlock (label + hint),
  search clear and folders (combined label).
- Rolling and odometer numbers expose the **final text** as one label and hide
  the individual animated glyphs.
- Toasts are live regions.
- Touch targets are at least 44 px for frequent actions (§4.2).
- Reduced motion is honoured (§8.10).
- The text scaler is respected, including in digit-cell measurement.
- Contrast: body text is pure `text` on `bg`. Secondary and tertiary greys are
  reserved for labels, never for key values.

---

## 13. Other surfaces

### Wear OS (`lib/wear/`)

The watch app always uses the **dark** theme, the same tokens and Nunito, but
adapts to a round screen:

- Lists are centred with **10% side padding**. The top 17% and bottom 24% are
  padding, and a vertical `ShaderMask` fades items out at the top and bottom
  edges.
- **Items shrink as they move away from the centre**, down to 78% scale at the
  edges (`_EdgeScale`), which gives a curved "fisheye" list that follows the
  round bezel.
- Rotary-crown input is supported through a method channel. Every
  crown/stepper tick gives a selection haptic.
- The same idioms appear in smaller form: a week ring in `accent`, pill
  buttons (filled `accent` with `bg` text for primary), a copper outline on
  today's routine, and a copper fire icon for the streak.

### Home-screen widgets (`widgets/home_widget_views.dart`)

These are rendered from the same `GymColors` (they follow the theme): a
`bgRaised` card with a `border` frame, a copper flame, big numerals (up to
46 px) and a mini heatmap using the chosen heat ramp.

### Share cards and stickers

- **Share card**: fixed at **340 × 425** (4:5). It has a vertical gradient
  from `bgRaised` to `bg`, a copper dot and brand line, a 1 px divider, and a
  hero number (66/700) or a stat grid with brass kickers.
- **Sticker editor**: overlays workout stats on a user photo. Text colours are
  limited to six swatches (§3.5), and a soft shadow is added on light
  swatches.

---

## 14. Checklist for new UI

Before shipping a new screen or component, check:

- [ ] Colours come from `context.gc`. There are no new hex values unless the
      palette belongs to one feature (and then it is documented here), and
      every colour works in **both** dark and light.
- [ ] Text uses `AppTheme.f` (or `s` / `d`) with Nunito. Hierarchy comes from
      **weight** (500 / 600 / 700 / 800) and **colour** (`text` /
      `textSecondary` / `textTertiary`), not many sizes.
- [ ] Section labels are uppercase kickers with letter-spacing. Everything
      else is sentence case (`titleCase` for buttons).
- [ ] Interactive elements are **pills**. Containers use radius 20–28, with
      smaller radii as elements nest.
- [ ] Layers use tone steps (`bg` → `bgRaised` → `bgRaised2`), not shadows.
- [ ] Taps give feedback with `Pressable` (never Material ripples) and the
      right **haptic** weight.
- [ ] Sheets and dialogs use `showAppSheet` / `showAppDialog` (blurred
      barrier), with a handle, `SheetTitle` and `sheetPad`.
- [ ] Feedback messages use `showNotchToast`, not snackbars.
- [ ] Entrances use `Rise` / `riseAll` inside a `RiseScope`. Changing numbers
      use `RollingText`.
- [ ] Motion uses `easeOutCubic` in and `easeInCubic` out, stays in the
      200–520 ms range for UI, and respects **reduced motion**.
- [ ] Touch targets are at least 44 px. Custom controls have `Semantics`.
- [ ] All text goes through `t.<key>`, survives long translations, and
      survives RTL.
- [ ] Copper `accent` is used for **one** thing on the screen.
