library hljs;

import 'dart:math';
import 'dart:html' as dom;
import 'dart:js' as js;
import 'package:angular/angular.dart';

_deindent(String str) {
  var lines = str
      .split('\n').map((line) => new RegExp(r"^\s*$").hasMatch(line) ? "" : line)
      .skipWhile((s) => s.isEmpty)
      .toList();
  final prefix = lines
       .where((line) => line != "")
       .map((line) => new RegExp(r"^\s*").firstMatch(line).group(0).length)
       .fold(9999, min);
  return lines
       .map((line) => line != "" ? line.substring(prefix) : line)
       .join('\n');
}

@NgComponent(
    selector: 'hljs',
    templateUrl: 'packages/NgTalk/hljs/hljs.html',
    cssUrls: const [
      'packages/NgTalk/hljs/hljs-theme.css',
      'packages/NgTalk/hljs/hljs.css'
    ],
    resetStyleInheritance: true,
    map: const {
      "source": "@source"
    }
)
class HighlightJS extends NgShadowRootAware {
  var _source = "";
  var host;

  onShadowRoot(root) {
    host = root.querySelector(".container");
    render();
  }

  set source (val) {
    _source = val != null ? _deindent(val) : val;
    if (host != null) render();
  }

  render() {
    final pre = new dom.PreElement()..text = _source;
    host.nodes.clear();
    host.nodes.add(pre);
    pre.classes.add('hljs');
    pre.classes.add('html');
    js.context['hljs'].callMethod('highlightBlock', [pre]);
  }
}