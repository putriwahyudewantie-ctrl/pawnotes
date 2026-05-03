class Note {
  String id;
  String title;
  String content;
  DateTime date;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  // Convert to Map for JSON / SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
    };
  }

  // Create Note from Map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: DateTime.parse(map['date']),
    );
  }
}
