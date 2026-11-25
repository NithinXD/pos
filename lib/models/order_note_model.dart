class OrderNoteModel {
  final int noteId;
  final String note;

  const OrderNoteModel({
    required this.noteId,
    required this.note,
  });

  factory OrderNoteModel.fromMap(Map<String, dynamic> map) {
    return OrderNoteModel(
      noteId: (map['note_id'] as int?) ?? 0,
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (noteId > 0) 'note_id': noteId,
      'note': note,
    };
  }

  OrderNoteModel copyWith({
    int? noteId,
    String? note,
  }) {
    return OrderNoteModel(
      noteId: noteId ?? this.noteId,
      note: note ?? this.note,
    );
  }
}
