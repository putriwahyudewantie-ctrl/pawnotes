class Note {
  String id;
  String title;
  String content;
  DateTime date;
  String? background;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.background,
  });

  // Convert to Map for JSON / SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'background': background
    };
  }

  // Create Note from Map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: DateTime.parse(map['date']),
      background: map['background'],
    );
  }

  Note copyWith({
  String? title,
  String? content,
  String? background,
}) {
  return Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    background: background ?? this.background,
    date: date,
  );
}

  
}


