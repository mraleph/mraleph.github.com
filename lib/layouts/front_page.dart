import 'package:intl/intl.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:collection/collection.dart';

import '../components/site_nav.dart';
import '../outputs/atom_output.dart';
import '../utils.dart';

class PageRef extends StatelessComponent {
  final Page page;

  const PageRef({super.key, required this.page});

  @override
  Component build(BuildContext context) {
    final date = page.date; // {{include.post.date | date:\'%b %Y\'}}
    final title = page.title;
    return article([
      h2([
        a(href: page.url, [
          .text(title),
        ]),
      ]),
      p([
        ..._withInlineCode(page.summary ?? ''),
        span(classes: 'date', [
          .text(DateFormat.yMMM().format(date)),
        ]),
      ]),
    ]);
  }

  static final _inlineCodePattern = RegExp(r'`([^`]+)`');

  /// Splits [text] into text and `<code>` components, treating Markdown-style
  /// `backtick` spans as inline code.
  static List<Component> _withInlineCode(String text) {
    final result = <Component>[];
    var start = 0;
    for (final m in _inlineCodePattern.allMatches(text)) {
      if (m.start > start) result.add(.text(text.substring(start, m.start)));
      result.add(code([.text(m[1]!)]));
      start = m.end;
    }
    if (start < text.length) result.add(.text(text.substring(start)));
    return result;
  }
}

class ListOfPosts extends StatelessComponent {
  const ListOfPosts({super.key});

  @override
  Component build(BuildContext context) {
    final posts = context.pages.where((p) => p.layout == 'blogpost').toList();
    final byYear = posts.groupListsBy((e) => e.date.year);

    return div(classes: 'posts', [
      for (var e in byYear.entries.sorted((l, r) => r.key.compareTo(l.key))) ...[
        h1([
          Component.text('${e.key}'),
        ]),
        div([
          for (var page in e.value..sort((l, r) => r.date.compareTo(l.date))) PageRef(page: page),
        ]),
      ],
    ]);
  }

  static final CustomComponent component = CustomComponent(
    pattern: 'ListOfPosts',
    builder: (name, attributes, child) {
      return ListOfPosts();
    },
  );
}

/// A single talk loaded from `content/_data/talks.yaml`.
class Talk {
  final String title;
  final DateTime date;
  final String? conference;
  final String? slides;
  final String? video;

  /// Paragraphs of the description. Might contain inline HTML.
  final List<String> description;

  Talk({
    required this.title,
    required this.date,
    this.conference,
    this.slides,
    this.video,
    this.description = const [],
  });

  factory Talk.fromYaml(Map<String, Object?> data) {
    String? optional(String key) {
      final value = data[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return Talk(
      title: data['title'].toString(),
      date: DateTime.parse(data['date'].toString()),
      conference: optional('conference'),
      slides: optional('slides'),
      video: optional('video'),
      description: [
        for (final line in (optional('description') ?? '').split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ],
    );
  }

  /// Loads all talks from the `talks` data file available to the current page.
  static List<Talk> all(BuildContext context) {
    final talks = context.page.data['talks'];
    if (talks is! List) return const [];
    return [
      for (final talk in talks)
        if (talk is Map) Talk.fromYaml(talk.cast<String, Object?>()),
    ];
  }
}

class TalkRef extends StatelessComponent {
  final Talk talk;

  const TalkRef({super.key, required this.talk});

  @override
  Component build(BuildContext context) {
    final links = [
      if (talk.slides case final slides?) (name: 'slides', href: slides),
      if (talk.video case final video?) (name: 'video', href: video),
    ];
    // Same date styling as in [PageRef].
    final date = span(classes: 'date', [
      .text(DateFormat.yMMM().format(talk.date)),
    ]);
    final paragraphs = talk.description.isEmpty ? const [''] : talk.description;

    return article([
      h2([.text(talk.title)]),
      if (talk.conference != null || links.isNotEmpty)
        p(classes: 'meta', [
          if (talk.conference case final conference?) span([.text(conference)]),
          for (final link in links) a(href: link.href, [.text('[${link.name}]')]),
        ]),
      for (final (i, paragraph) in paragraphs.indexed)
        p([
          RawText(paragraph),
          if (i == paragraphs.length - 1) date,
        ]),
    ]);
  }
}

class ListOfTalks extends StatelessComponent {
  const ListOfTalks({super.key});

  @override
  Component build(BuildContext context) {
    final byYear = Talk.all(context).groupListsBy((e) => e.date.year);

    return div(classes: 'talks', [
      for (var e in byYear.entries.sorted((l, r) => r.key.compareTo(l.key))) ...[
        h1([
          Component.text('${e.key}'),
        ]),
        div([
          for (var talk in e.value..sort((l, r) => r.date.compareTo(l.date))) TalkRef(talk: talk),
        ]),
      ],
    ]);
  }

  static final CustomComponent component = CustomComponent(
    pattern: 'ListOfTalks',
    builder: (name, attributes, child) {
      return ListOfTalks();
    },
  );
}

class FrontPageLayout extends PageLayoutBase {
  const FrontPageLayout();

  @override
  Pattern get name => 'front_page';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    // Add common meta tags.
    yield* super.buildHead(page);
    yield link(href: 'css/styles.css', rel: 'stylesheet');
    yield atomFeedLink;
  }

  static final socialMedia = [
    (
      name: 'GitHub',
      href: 'https://github.com/mraleph',
      icon: svg(
        viewBox: '0 0 16 16',
        attributes: {
          'width': '24',
          'height': '24',
          'fill': 'currentColor',
          'aria-hidden': 'true',
          'xmlns': 'http://www.w3.org/2000/svg',
        },
        [
          path(
            d: 'M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z',
            [],
          ),
        ],
      ),
    ),
    (
      name: 'LinkedIn',
      href: 'https://www.linkedin.com/in/mraleph/',
      icon: svg(
        viewBox: '0 0 24 24',
        attributes: {
          'width': '24',
          'height': '24',
          'fill': 'currentColor',
          'aria-hidden': 'true',
          'xmlns': 'http://www.w3.org/2000/svg',
        },
        [
          path(
            d: 'M20.5 2h-17A1.5 1.5 0 002 3.5v17A1.5 1.5 0 003.5 22h17a1.5 1.5 0 001.5-1.5v-17A1.5 1.5 0 0020.5 2zM8 19H5v-9h3zM6.5 8.25A1.75 1.75 0 118.3 6.5a1.78 1.78 0 01-1.8 1.75zM19 19h-3v-4.74c0-1.42-.6-1.93-1.38-1.93A1.74 1.74 0 0013 14.19a.66.66 0 000 .14V19h-3v-9h2.9v1.3a3.11 3.11 0 012.7-1.4c1.55 0 3.36.86 3.36 3.66z',
            [],
          ),
        ],
      ),
    ),
    (
      name: 'X',
      href: 'https://x.com/mraleph/',
      icon: svg(
        viewBox: '0 0 1200 1227',
        attributes: {
          'width': '24',
          'height': '24',
          'fill': 'currentColor',
          'xmlns': 'http://www.w3.org/2000/svg',
        },
        [
          path(
            d: 'M714.163 519.284L1160.89 0H1055.03L667.137 450.887L357.328 0H0L468.492 681.821L0 1226.37H105.866L515.491 750.218L842.672 1226.37H1200L714.137 519.284H714.163ZM569.165 687.828L521.697 619.934L144.011 79.6944H306.615L611.412 515.685L658.88 583.579L1055.08 1150.3H892.476L569.165 687.854V687.828Z',
            [],
          ),
        ],
      ),
    ),
    (
      name: 'Bluesky',
      href: 'https://bsky.app/profile/mrale.ph',
      icon: svg(
        viewBox: '0 0 600 530',
        attributes: {
          'width': '24',
          'height': '24',
          'fill': 'currentColor',
          'xmlns': 'http://www.w3.org/2000/svg',
        },
        [
          path(
            d: 'm135.72 44.03c66.496 49.921 138.02 151.14 164.28 205.46 26.262-54.316 97.782-155.54 164.28-205.46 47.98-36.021 125.72-63.892 125.72 24.795 0 17.712-10.155 148.79-16.111 170.07-20.703 73.984-96.144 92.854-163.25 81.433 117.3 19.964 147.14 86.092 82.697 152.22-122.39 125.59-175.91-31.511-189.63-71.766-2.514-7.3797-3.6904-10.832-3.7077-7.8964-0.0174-2.9357-1.1937 0.51669-3.7077 7.8964-13.714 40.255-67.233 197.36-189.63 71.766-64.444-66.128-34.605-132.26 82.697-152.22-67.108 11.421-142.55-7.4491-163.25-81.433-5.9562-21.282-16.111-152.36-16.111-170.07 0-88.687 77.742-60.816 125.72-24.795z', [
                      ],
          ),
        ],
      ),
    ),
    (
      name: 'Mail',
      href: 'mailto:me@mrale.ph',
      icon: svg(
        viewBox: '0 -960 960 960',
        attributes: {
          'height': '24px',
          'width': '24px',
          'fill': 'currentColor',
          'xmlns': 'http://www.w3.org/2000/svg',
        },
        [
          path(
            d: 'M160-160q-33 0-56.5-23.5T80-240v-480q0-33 23.5-56.5T160-800h640q33 0 56.5 23.5T880-720v480q0 33-23.5 56.5T800-160H160Zm320-280L160-640v400h640v-400L480-440Zm0-80 320-200H160l320 200ZM160-640v-80 480-400Z',
            [],
          ),
        ],
      ),
    ),
  ];

  /// Styles are in `_front_page.scss`.
  @override
  Component buildBody(Page page, Component child) {
    return div([
      Document.body(attributes: {'class': 'front-page'}),
      header([
        h1([
          Component.text('Slava Egorov'),
        ]),
        ul(classes: 'social', attributes: {'aria-label': 'Social media'}, [
          for (final (:name, :href, :icon) in socialMedia)
            li([
              a(
                href: href,
                target: Target.blank,
                attributes: {
                  'rel': 'noreferrer noopener',
                  'aria-label': '$name (opens in a new tab)',
                  'title': name,
                },
                [
                  span([
                    Component.text(name),
                  ]),
                  icon,
                ],
              ),
            ]),
        ]),
        const SiteNav(),
      ]),
      main_([child]),
    ]);
  }
}
