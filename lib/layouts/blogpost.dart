import 'package:intl/intl.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:mraleph/components/site_nav.dart';
import 'package:mraleph/outputs/atom_output.dart';
import 'package:mraleph/utils.dart';

class BlogpostLayout extends PageLayoutBase {
  const BlogpostLayout();

  @override
  Pattern get name => 'blogpost';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    // Add common meta tags.
    yield* super.buildHead(page);
    yield link(href: 'css/styles.css', rel: 'stylesheet');
    yield atomFeedLink;
  }

  /// Styles are in `_blogpost.scss`.
  @override
  Component buildBody(Page page, Component child) {
    return article([
      Document.body(attributes: {'class': 'blogpost'}),
      header([
        const SiteNav(compact: true),
        div([
          h1([
            .text(page.title),
          ]),
          Component.element(
            tag: 'time',
            attributes: {'datetime': DateFormat('yyyy-MM-dd').format(page.date)},
            children: [
              .text(DateFormat.yMMMd().format(page.date)),
            ],
          ),
        ]),
      ]),
      child,
      p(classes: 'comments', [
        span([
          .text('Comments?'),
        ]),
        .text('''

            Drop me a mail '''),
        code([
          .text('me@mrale.ph'),
        ]),
        .text(''' or find me on
            '''),
        a(href: 'https://mastodon.social/@mraleph', [
          .text('Mastodon'),
        ]),
        .text(''',
            '''),
        a(href: 'https://x.com/mraleph', [
          .text('X'),
        ]),
        .text(' or '),
        a(href: 'https://bsky.app/profile/mrale.ph', [
          .text('Bluesky'),
        ]),
        .text('''.
          '''),
      ]),
    ]);
  }
}
