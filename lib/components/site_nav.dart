import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

/// Site-wide navigation between top-level sections (posts and talks).
///
/// The current section is derived from the URL of the page being rendered.
/// Styles are in `_site_nav.scss`.
class SiteNav extends StatelessComponent {
  /// Renders a small right-aligned row of links without line indicators
  /// (used on blog post pages) instead of the large sidebar navigation.
  final bool compact;

  const SiteNav({super.key, this.compact = false});

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
    return nav(classes: compact ? 'site-nav compact' : 'site-nav', attributes: {'aria-label': 'Site sections'}, [
      ul([
        for (final section in sections) _link(section.name, section.href, active: section == current),
      ]),
    ]);
  }

  Component _link(String name, String href, {required bool active}) {
    return li([
      a(
        href: href,
        attributes: {if (active) 'aria-current': 'page'},
        [
          // Horizontal line indicator, only shown on large screens where the
          // navigation is laid out vertically.
          if (!compact) span([]),
          .text(name),
        ],
      ),
    ]);
  }
}
