class RestaurantModel {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String status; // 'active', 'open', 'closed'
  final String currency;
  final int numberOfTables;
  final String gstnNumber;
  final bool printKotSeparate;
  final String createdAt;
  final String updatedAt;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.status = 'active',
    this.currency = '₹',
    this.numberOfTables = 10,
    this.gstnNumber = '',
    this.printKotSeparate = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    final kotVal = map['print_kot'] ?? map['print_KOT'] ?? 0;
    final isKotSeparate = kotVal == 1 || kotVal == true || kotVal == '1';
    return RestaurantModel(
      id: map['restaurant_id'] as int,
      name: map['restaurant_name'] as String? ?? '',
      phone: map['restaurant_phone'] as String? ?? '',
      address: map['restaurant_address'] as String? ?? '',
      status: map['restaurant_status'] as String? ?? 'active',
      currency: map['restaurant_currency'] as String? ?? '₹',
      numberOfTables: map['number_of_tables'] as int? ?? 10,
      gstnNumber: map['restaurant_gstn'] as String? ?? map['restaurant_gstin'] as String? ?? '',
      printKotSeparate: isKotSeparate,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurant_id': id,
      'restaurant_name': name,
      'restaurant_phone': phone,
      'restaurant_address': address,
      'restaurant_status': status,
      'restaurant_currency': currency,
      'number_of_tables': numberOfTables,
      'restaurant_gstn': gstnNumber,
      'print_kot': printKotSeparate ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  RestaurantModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? status,
    String? currency,
    int? numberOfTables,
    String? gstnNumber,
    bool? printKotSeparate,
    String? updatedAt,
  }) {
    return RestaurantModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      numberOfTables: numberOfTables ?? this.numberOfTables,
      gstnNumber: gstnNumber ?? this.gstnNumber,
      printKotSeparate: printKotSeparate ?? this.printKotSeparate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
