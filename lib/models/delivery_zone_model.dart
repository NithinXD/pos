class DeliveryZoneModel {
  final int id;
  final String deliveryArea;
  final double deliveryCharge;

  const DeliveryZoneModel({
    required this.id,
    required this.deliveryArea,
    required this.deliveryCharge,
  });

  factory DeliveryZoneModel.fromMap(Map<String, dynamic> map) {
    return DeliveryZoneModel(
      id: map['id'] as int,
      deliveryArea: map['delivery_area'] as String? ?? '',
      deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'delivery_area': deliveryArea,
      'delivery_charge': deliveryCharge,
    };
  }

  DeliveryZoneModel copyWith({
    int? id,
    String? deliveryArea,
    double? deliveryCharge,
  }) {
    return DeliveryZoneModel(
      id: id ?? this.id,
      deliveryArea: deliveryArea ?? this.deliveryArea,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
    );
  }
}
