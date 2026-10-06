import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart' hide Color;

/// A code block component that renders syntax-highlighted code.
class CodeBlock extends CustomComponent {
  CodeBlock({this.defaultLanguage = 'dart', this.grammars = const {}, this.codeTheme}) : super.base();

  static Component from({required String source, Highlighter? highlighter, Key? key}) {
    return _CodeBlock(source: source, highlighter: highlighter, key: key);
  }

  /// The default language for the code block.
  final String defaultLanguage;

  /// The available grammars for the code block.
  ///
  /// The key is the name of the language.
  /// The value is a json encoded string of the grammar.
  final Map<String, String> grammars;

  /// The default theme for the code block.
  final HighlighterTheme? codeTheme;

  bool _initialized = false;
  HighlighterTheme? _defaultTheme;

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(tag: 'pre', :final attributes)
        when (attributes['class']?.contains('no-highlight') ?? false)) {
      // Highlighting is disabled.
      return null;
    }

    if (node
        case ElementNode(tag: 'Code' || 'CodeBlock', :final children, :final attributes) ||
            ElementNode(tag: 'pre', children: [ElementNode(tag: 'code', :final children, :final attributes)])) {
      var language = attributes['language'];
      if (language == null && (attributes['class']?.startsWith('language-') ?? false)) {
        language = attributes['class']!.substring('language-'.length);
      }

      if (!_initialized) {
        Highlighter.initialize(['dart']);
        for (final entry in grammars.entries) {
          Highlighter.addLanguage(entry.key, entry.value);
        }
        _initialized = true;
      }

      return AsyncBuilder(
        builder: (context) async {
          try {
            final highlighter = Highlighter(
              language: language ?? defaultLanguage,
              theme: codeTheme ?? (_defaultTheme ??= await HighlighterTheme.loadDarkTheme()),
            );

            return _CodeBlock(source: children?.map((c) => c.innerText).join(' ') ?? '', highlighter: highlighter);
          } catch (e) {
            throw StateError('Failed to highlight ${language ?? defaultLanguage}');
          }
        },
      );
    }
    return null;
  }
}

final scopeClasses = <String, String?>{
  'keyword': 'k',
  'keyword.operator': 'o',
  'storage': 'k',
  'comment': 'c',
  'string': 's',
  'constant.numeric': 'm',
  'markup.inserted.diff': 'gi',
  'markup.deleted.diff': 'gd',
  'meta.diff': 'c',
};

String? lookupClassForScope(String v) {
  if (scopeClasses.containsKey(v)) {
    return scopeClasses[v];
  }
  final lastDot = v.lastIndexOf('.');
  return scopeClasses[v] = lastDot == -1 ? null : lookupClassForScope(v.substring(0, lastDot));
}

List<String> classesFor(List<String> scopes) {
  return scopes.map(lookupClassForScope).nonNulls.toList();
}

/// A code block component with syntax highlighting.
class _CodeBlock extends StatelessComponent {
  const _CodeBlock({required this.source, this.highlighter, super.key});

  /// The source code of the code block.
  final String source;

  /// The syntax highlighter instance.
  final Highlighter? highlighter;

  @override
  Component build(BuildContext context) {
    final codeblock = pre(classes: 'highlight', [
      code([if (highlighter != null) buildSpan(highlighter!.highlight(source)) else text(source)]),
    ]);

    return codeblock;
  }

  Component buildSpan(TextSpan textSpan) {
    // Styles? styles;

    // if (textSpan.style case final style?) {
    //  styles = Styles(
    //    color: Color.value(style.foreground.argb & 0x00FFFFFF),
    //    fontWeight: style.bold ? FontWeight.bold : null,
    //    fontStyle: style.italic ? FontStyle.italic : null,
    //    textDecoration: style.underline ? TextDecoration(line: TextDecorationLine.underline) : null,
    //  );
    // }

    final children = textSpan.children.isEmpty
        ? [Component.text(textSpan.text ?? '')]
        : [
            for (var t in textSpan.children) buildSpan(t),
          ];

    final classes = classesFor(textSpan.scopes);
    if (classes.isEmpty) {
      return .fragment(children);
    }
    return span(classes: classes.join(' '), children);
  }
}
