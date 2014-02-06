library display;

import 'dart:html' as dom;
import 'package:angular/angular.dart';

@NgComponent(
    selector: 'view-source',
    templateUrl: 'packages/NgTalk/view-source/view-source.html',
    cssUrls: const ['packages/NgTalk/view-source/view-source.css'],
    publishAs: 'self'
)
class ViewSource {
  var template;

  ViewSource(dom.Element element) {
    final div = new dom.DivElement();
    
    clone(n) {
      if (n is dom.Comment) {
        final nodes = ANCHOR2NODES[n];
        if (nodes != null) {
          nodes.forEach(clone);
          return;
        }
      }
      div.nodes.add(n.clone(true));
    }
    
    element.nodes.forEach(clone);
    
    template = _clean(div.innerHtml);    
    if (template.contains("ANCHOR")) {
      print(template);
    }
  }
}

_clean(String val) => val.replaceAllMapped(new RegExp(r'([-\w]+)=""', multiLine: true), (m) => m.group(1));