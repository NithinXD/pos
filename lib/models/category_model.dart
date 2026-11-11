class CategoryModel {
  final int id;
  final String name;
  final int position;
  final String colorHex;
  final String type; // 'food', 'drinks', 'desserts', 'retail'
  final int status; // 1 = enabled, 0 = disabled

  const CategoryModel({
    required this.id,
    required this.name,
    this.position = 0,
    this.colorHex = '#4CAF50',
    this.type = 'food',
    this.status = 1,
  });

  bool get isEnabled => status == 1;

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['category_id'] as int? ?? 0,
      name: map['category_name'] as String? ?? '',
      position: map['category_position'] as int? ?? 0,
      colorHex: map['category_colour'] as String? ?? '#4CAF50',
      type: map['category_type'] as String? ?? 'food',
      status: map['category_status'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'category_id': id,
      'category_name': name,
      'category_position': position,
      'category_colour': colorHex,
      'category_type': type,
      'category_status': status,
    };
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    int? position,
    String? colorHex,
    String? type,
    int? status,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }
}
