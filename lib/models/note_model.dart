class Note {
  String id;
  String title;
  String content;
  DateTime date;
  DateTime? reminderDate;
  DateTime? selectedDate;
  String? imageUrl;
  String folder;
  bool isArchived;
  bool isPrivate;
  List<String> attachments;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.reminderDate,
    this.selectedDate,
    this.imageUrl,
    this.folder = 'Umum',
    this.isArchived = false,
    this.isPrivate = false,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'date': date.toIso8601String(),
    'reminderDate': reminderDate?.toIso8601String(),
    'selectedDate': selectedDate?.toIso8601String(),
    'imageUrl': imageUrl,
    'folder': folder,
    'isArchived': isArchived,
    'isPrivate': isPrivate,
    'attachments': attachments,
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    date: DateTime.parse(map['date'] as String),
    reminderDate: map['reminderDate'] == null
        ? null
        : DateTime.parse(map['reminderDate'] as String),
    selectedDate: map['selectedDate'] == null
        ? null
        : DateTime.parse(map['selectedDate'] as String),
    imageUrl: map['imageUrl'] as String?,
    folder: map['folder'] as String? ?? 'Umum',
    isArchived: map['isArchived'] as bool? ?? false,
    isPrivate: map['isPrivate'] as bool? ?? false,
    attachments: (map['attachments'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
  );
}
