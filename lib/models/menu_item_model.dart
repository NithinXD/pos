class MenuItemModel {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final double sitdownPrice;
  final double takeawayPrice;
  final double deliveryPrice;
  final int quantity;
  final String itemType; // 'veg', 'non-veg', 'vegan', 'beverage'
  final String kitchenType; // 'hot_kitchen', 'bar', 'cold_kitchen', 'bakery'
  final double taxRate;
  final int status; // 1 = enabled, 0 = disabled
  final bool isAvailable;

  const MenuItemModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.sitdownPrice,
    this.takeawayPrice = 0.0,
    this.deliveryPrice = 0.0,
    this.quantity = 100,
    this.itemType = 'veg',
    this.kitchenType = 'hot_kitchen',
    this.taxRate = 5.0,
    this.status = 1,
    this.isAvailable = true,
  });

  bool get isVeg => itemType == 'veg';
  bool get isNonVeg => itemType == 'non-veg';
  bool get isVegan => itemType == 'vegan';
  bool get isBeverage => itemType == 'beverage';
  bool get isEnabled => status == 1;

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    final s = map['item_status'] as int? ?? 1;
    return MenuItemModel(
      id: map['item_id'] as int? ?? 0,
      categoryId: map['category_id'] as int? ?? 1,
      categoryName: map['category_name'] as String? ?? 'General',
      name: map['item_name'] as String? ?? '',
      sitdownPrice: (map['item_sitdown_price'] as num?)?.toDouble() ?? 0.0,
      takeawayPrice: (map['item_takeaway_price'] as num?)?.toDouble() ?? 0.0,
      deliveryPrice: (map['item_delivery_price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['item_quantity'] as int? ?? 100,
      itemType: map['item_type'] as String? ?? 'veg',
      kitchenType: map['item_kitchen_type'] as String? ?? 'hot_kitchen',
      taxRate: (map['item_tax_rate'] as num?)?.toDouble() ?? 5.0,
      status: s,
      isAvailable: s == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'item_id': id,
      'category_id': categoryId,
      'item_name': name,
      'item_sitdown_price': sitdownPrice,
      'item_takeaway_price': takeawayPrice,
      'item_delivery_price': deliveryPrice,
      'item_quantity': quantity,
      'item_type': itemType,
      'item_kitchen_type': kitchenType,
      'item_tax_rate': taxRate,
      'item_status': status,
    };
  }

  double priceFor({bool isTakeaway = false}) {
    if (isTakeaway && takeawayPrice > 0) {
      return takeawayPrice;
    }
    return sitdownPrice;
  }

  MenuItemModel copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? name,
    double? sitdownPrice,
    double? takeawayPrice,
    double? deliveryPrice,
    int? quantity,
    String? itemType,
    String? kitchenType,
    double? taxRate,
    int? status,
    bool? isAvailable,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      sitdownPrice: sitdownPrice ?? this.sitdownPrice,
      takeawayPrice: takeawayPrice ?? this.takeawayPrice,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      quantity: quantity ?? this.quantity,
      itemType: itemType ?? this.itemType,
      kitchenType: kitchenType ?? this.kitchenType,
      taxRate: taxRate ?? this.taxRate,
      status: status ?? this.status,
      isAvailable: isAvailable ?? (status != null ? status == 1 : this.isAvailable),
    );
  }
}

class CartItemModel {
  final MenuItemModel item;
  int quantity;
  String? notes;
  String status; // 'ordered', 'preparing', 'served'
  final int existingQuantity; // Quantity already held/sent to kitchen
  final bool isTakeaway;
  final double? customUnitPrice;

  CartItemModel({
    required this.item,
    this.quantity = 1,
    this.notes,
    this.status = 'ordered',
    this.existingQuantity = 0,
    this.isTakeaway = false,
    this.customUnitPrice,
  });

  bool get isExisting => existingQuantity > 0;
  bool get canDelete => existingQuantity == 0;
  bool get canDecrement => quantity > existingQuantity;
  int get newQuantity => quantity > existingQuantity ? (quantity - existingQuantity) : 0;

  double get unitPrice {
    if (customUnitPrice != null && customUnitPrice! > 0) {
      return customUnitPrice!;
    }
    return (isTakeaway && item.takeawayPrice > 0) ? item.takeawayPrice : item.sitdownPrice;
  }

  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({
    MenuItemModel? item,
    int? quantity,
    String? notes,
    String? status,
    int? existingQuantity,
    bool? isTakeaway,
    double? customUnitPrice,
  }) {
    return CartItemModel(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      existingQuantity: existingQuantity ?? this.existingQuantity,
      isTakeaway: isTakeaway ?? this.isTakeaway,
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
    );
  }
}
