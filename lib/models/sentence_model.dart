class Sentence {
  String content;
  int id;
  bool isAnnotated;

  Sentence({
    required this.content,
    required this.id,
    required this.isAnnotated,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      content: json['content'],
      id: json['id'],
      isAnnotated: json['is_annotated'],
    );
  }
}
