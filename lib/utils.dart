import 'package:jaspr_content/jaspr_content.dart';

extension PageAttributes on Page {
  Map<String, dynamic>? get frontMatter => (data['page'] as Map<String, dynamic>?);
  String get layout => frontMatter?['layout'] ?? '';
  DateTime get date => DateTime.tryParse(frontMatter?['date'] ?? '')!;
  String get title => frontMatter?['title']!;
  String? get summary => frontMatter?['summary'];
}
