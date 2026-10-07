import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../utils.dart';

/// `<link rel="alternate">` advertising the Atom feed produced by [AtomOutput].
///
/// Should be included into the `<head>` of every layout so that browsers and
/// feed readers can discover the feed.
const Component atomFeedLink = link(
  href: '/atom.xml',
  rel: 'alternate',
  type: 'application/atom+xml',
  attributes: {'title': 'mrale.ph'},
);

/// Generates `/atom.xml` with an Atom feed of all blog posts.
///
/// Attached as a secondary output of the root `index.md` page so that it
/// gets exactly one route and has access to all loaded pages.
class AtomOutput extends SecondaryOutput {
  AtomOutput({
    this.siteUrl = 'https://mrale.ph',
    this.title = 'mrale.ph',
    this.authorName = 'Vyacheslav Egorov',
    this.authorEmail = 'me@mrale.ph',
  });

  final String siteUrl;
  final String title;
  final String authorName;
  final String authorEmail;

  @override
  final Pattern pattern = RegExp(r'index\.md$');

  @override
  String createRoute(String route) => '/atom.xml';

  @override
  Component build(Page page) {
    return Builder(
      builder: (context) {
        context.setHeader('Content-Type', 'application/atom+xml; charset=utf-8');
        context.setStatusCode(200, responseBody: renderFeed(context.pages));
        return Component.text('');
      },
    );
  }

  static final _xmlDate = DateFormat("yyyy-MM-dd'T'HH:mm:ss'+00:00'");

  static String _formatDate(DateTime d) => _xmlDate.format(DateTime.utc(d.year, d.month, d.day));

  static const _esc = _XmlEscape();

  /// Matches `blog/YYYY-MM-DD-slug.ext`.
  static final _postPath = RegExp(r'^blog/(\d{4})-(\d{2})-(\d{2})-(.+)\.\w+$');

  /// Entry id compatible with the one produced by the old Jekyll feed
  /// (`/blog/YYYY/MM/DD/slug`) so that feed readers don't treat existing
  /// posts as new ones.
  String _entryId(Page post) {
    if (_postPath.firstMatch(post.path) case final m?) {
      return '$siteUrl/blog/${m[1]}/${m[2]}/${m[3]}/${m[4]}';
    }
    return '$siteUrl${post.url}';
  }

  String renderFeed(List<Page> pages) {
    final posts = pages.where((page) => page.layout == 'blogpost').sortedBy((page) => page.date).reversed.toList();
    final updated = posts.isEmpty ? DateTime.now() : posts.first.date;

    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<feed xmlns="http://www.w3.org/2005/Atom">')
      ..writeln('  <title>${_esc.convert(title)}</title>')
      ..writeln('  <link href="$siteUrl"/>')
      ..writeln('  <link type="application/atom+xml" rel="self" href="$siteUrl/atom.xml"/>')
      ..writeln('  <updated>${_formatDate(updated)}</updated>')
      ..writeln('  <id>$siteUrl/</id>')
      ..writeln('  <author>')
      ..writeln('    <name>${_esc.convert(authorName)}</name>')
      ..writeln('    <email>${_esc.convert(authorEmail)}</email>')
      ..writeln('  </author>');

    for (final post in posts) {
      final url = '$siteUrl${post.url}';
      final date = _formatDate(post.date);
      final summary = post.summary?.trim();
      out
        ..writeln('  <entry>')
        ..writeln('    <id>${_esc.convert(_entryId(post))}</id>')
        ..writeln('    <link type="text/html" rel="alternate" href="${_esc.convert(url)}"/>')
        ..writeln('    <title>${_esc.convert(post.title)}</title>')
        ..writeln('    <published>$date</published>')
        ..writeln('    <updated>$date</updated>')
        ..writeln('    <author>')
        ..writeln('      <name>${_esc.convert(authorName)}</name>')
        ..writeln('      <uri>$siteUrl</uri>')
        ..writeln('    </author>');
      if (summary != null && summary.isNotEmpty) {
        out.writeln('    <summary>${_esc.convert(summary)}</summary>');
      }
      out
        ..writeln('    <content type="html">${_esc.convert('<a href="$url">read it here</a>')}</content>')
        ..writeln('  </entry>');
    }

    out.writeln('</feed>');
    return out.toString();
  }
}

/// Escapes the characters which are special in XML text and attribute values.
class _XmlEscape {
  const _XmlEscape();

  static final _special = RegExp('[&<>"\']');

  String convert(String text) => text.replaceAllMapped(
    _special,
    (m) => switch (m[0]) {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      _ => '&apos;',
    },
  );
}
