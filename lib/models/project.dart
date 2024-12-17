class Project {
  final String description;
  final int id;
  final String language;
  String title;

  Project(
      {required this.description,
      required this.id,
      required this.language,
      required this.title});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      description: json['description'],
      id: json['id'],
      language: json['language'],
      title: json['title'],
    );
  }
}
