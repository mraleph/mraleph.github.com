import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

/// Site-wide navigation between top-level sections (posts and talks).
///
/// The current section is derived from the URL of the page being rendered.
class SiteNav extends StatelessComponent {
  /// Renders a small right-aligned row of links without line indicators
  /// (used on blog post pages) instead of the large sidebar navigation.
  final bool compact;

  /// Additional classes applied to the `<nav>` element.
  final String? classes;

  const SiteNav({super.key, this.compact = false, this.classes});

  static const postsSection = (name: 'Posts', href: 'index.html');
  static const talksSection = (name: 'Talks', href: 'talks/index.html');
  static const sections = [postsSection, talksSection];

  /// Returns the section [url] belongs to, or `null` if it is not the landing
  /// page of any section (e.g. a blog post).
  static ({String name, String href})? sectionOf(String url) {
    final segments = Uri.parse(url).pathSegments.where((segment) => segment.isNotEmpty).toList();
    return switch (segments) {
      [] || ['index.html'] => postsSection,
      ['talks', ...] => talksSection,
      _ => null,
    };
  }

  @override
  Component build(BuildContext context) {
    final current = sectionOf(context.page.url);
    return nav(classes: ['site-nav', ?classes].join(' '), attributes: {'aria-label': 'Site sections'}, [
      ul(classes: compact ? 'flex gap-6 justify-end' : 'flex gap-6 lg:flex-col lg:gap-3', [
        for (final section in sections) _link(section.name, section.href, active: section == current),
      ]),
    ]);
  }

  Component _link(String name, String href, {required bool active}) {
    return li([
      a(
        classes: 'group flex items-center ${active ? 'text-lk' : 'hover:text-lk'}',
        href: href,
        attributes: {if (active) 'aria-current': 'page'},
        [
          if (!compact)
            // Horizontal line indicator, only shown on large screens where the
            // navigation is laid out vertically.
            span(
              classes: 'mr-4 hidden h-px bg-current transition-all lg:block ${active ? 'w-16' : 'w-8 group-hover:w-16'}',
              [],
            ),
          span(
            classes: 'equity-caps font-bold tracking-widest ${compact ? 'text-base' : 'text-xl'}',
            [.text(name)],
          ),
        ],
      ),
    ]);
  }
}
