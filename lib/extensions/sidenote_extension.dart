import 'package:jaspr_content/jaspr_content.dart';

/// Groups a standalone sidenote (a paragraph which contains nothing but a
/// `<sidenote>`) together with the element preceding it:
///
/// ```html
/// <div class="sidenote-group">
///   <p>...</p>
///   <p><sidenote>...</sidenote></p>
/// </div>
/// ```
///
/// On wide screens `.sidenote-group` becomes the containing block for the
/// absolutely positioned sidenote, which allows CSS to align the top of the
/// sidenote with the top of the preceding element.
///
/// Sidenotes which are embedded into a paragraph alongside other text are left
/// untouched: they are aligned with the line they are attached to.
class SidenoteExtension implements PageExtension {
  const SidenoteExtension();

  @override
  Future<List<Node>> apply(Page page, List<Node> nodes) async => _process(nodes);

  static List<Node> _process(List<Node> nodes) {
    final result = <Node>[];
    for (final node in nodes) {
      if (node is! ElementNode) {
        result.add(node);
        continue;
      }

      if (_isStandaloneSidenote(node)) {
        final prevIndex = result.lastIndexWhere((n) => !_isWhitespace(n));
        final prev = prevIndex >= 0 ? result[prevIndex] : null;
        if (prev is ElementNode && !_isStandaloneSidenote(prev) && !_isGroup(prev)) {
          result
            ..removeRange(prevIndex, result.length)
            ..add(ElementNode('div', {'class': 'sidenote-group'}, [prev, node]));
          continue;
        }
        result.add(node);
        continue;
      }

      final children = node.children;
      result.add(children == null ? node : ElementNode(node.tag, node.attributes, _process(children)));
    }
    return result;
  }

  static bool _isGroup(ElementNode node) => node.tag == 'div' && node.attributes['class'] == 'sidenote-group';

  /// Returns `true` if [node] is a `<p>` which contains a single `<sidenote>`
  /// and nothing else (apart from whitespace).
  static bool _isStandaloneSidenote(ElementNode node) {
    if (node.tag != 'p') return false;
    final children = node.children;
    if (children == null) return false;
    var sidenotes = 0;
    for (final child in children) {
      if (child is ElementNode && child.tag == 'sidenote') {
        sidenotes++;
      } else if (!_isWhitespace(child)) {
        return false;
      }
    }
    return sidenotes == 1;
  }

  static bool _isWhitespace(Node node) => node is TextNode && node.text.trim().isEmpty;
}
