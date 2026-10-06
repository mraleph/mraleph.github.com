import 'package:intl/intl.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:mraleph/utils.dart';

class BlogpostLayout extends PageLayoutBase {
  const BlogpostLayout();

  @override
  Pattern get name => 'blogpost';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    // Add common meta tags.
    yield* super.buildHead(page);
    yield link(href: 'css/fonts/mbtype/equity-light.css', rel: 'stylesheet');
    yield link(href: 'css/fonts/mbtype/concourse-index.css', rel: 'stylesheet');
    yield link(href: 'css/styles.css', rel: 'stylesheet');

    // yield Style(styles: [
    //  css('.custom_layout', [
    //    // Add custom css rules for this layout.
    //  ]),
    // ]);
  }

  @override
  Component buildBody(Page page, Component child) {
    return div(classes: 'flex lg:justify-center max-lg:px-6 w-full max-w-full', [
      Document.body(attributes: {'class': 'pt-6 w-full blogpost'}),
      div(classes: 'w-full lg:max-w-[800px] md:text-xl relative', [
        div(classes: 'title', [
          div(classes: 'border-t-3', [
            div(classes: 'mb-2', [
              .text(page.title!),
            ]),
            Component.element(
              tag: 'time',
              attributes: {'class': 'text-lg lowercase text-tbg', 'datetime': '{{ page.date }}'},
              children: [
                .text(DateFormat.yMMMd().format(page.date!)),
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
      ]),
    ]);
  }
}
