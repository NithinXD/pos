import 'dart:ffi';
class Order {
  final String orderId;
  final String status;
  final String orderTime;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double total;
  final String orderPrinted;
  final List<Item> items;
  final String orderType;
  final double deliveryFee;
  final double orderTotal;
  final String email;

  // Fields for shop details
  final String shopId;
  final String shopName; // Ensure this field is present
  final String shopAddress; // Ensure this field is present
  final String shopTelephone; // Ensure this field is present
  final String paymentType;
  final double discount;

  Order({
    required this.orderId,
    required this.status,
    required this.orderTime,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.total,
    required this.orderPrinted,
    required this.orderType,
    required this.deliveryFee,
    required this.orderTotal,
    required this.email,
    required this.items,
    required this.shopId,
    required this.shopName, // Ensure this field is initialized
    required this.shopAddress, // Ensure this field is initialized
    required this.shopTelephone, // Ensure this field is initialized
    required this.paymentType,
    required this.discount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double total = double.tryParse(json['od_total'] ?? '0') ?? 0.0;
    double discount = double.tryParse(json['od_discount'] ?? '0') ?? 0.0;
print(json);
    return Order(
      orderId: json['od_id'] ?? '',
      status: json['od_status'] ?? '',
      orderTime: json['od_date'] ?? '',
      customerName: '${json['od_shipping_first_name']} ${json['od_shipping_last_name']}',
      customerPhone: json['od_shipping_phone'] ?? '',
      customerAddress: '${json['od_shipping_address1']}, ${json['od_shipping_address2']}, ${json['od_shipping_city']}, ${json['od_shipping_state']}, ${json['od_shipping_postal_code']}',
      total: total,
      orderPrinted: json['order_printed'] ?? "0",
      orderType: json['od_delivery'] ?? '',
      deliveryFee: double.tryParse(json['od_delivery_charge'] ?? '0') ?? 0.0,
      orderTotal: total - discount,
      email: json['email'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => Item.fromJson(item))
          .toList() ?? [],
      shopId: json['shop_id'] ?? '',
      shopName: json['shop_name'] ?? '', // Ensure this field is populated
      shopAddress: '${json['housenameno']}, ${json['area']}, ${json['city']}, ${json['postcode']}, ${json['state']}, ${json['country']}',
      shopTelephone: json['telephone'] ?? '',
      paymentType: json['od_payment_type'] ?? '',
      discount: double.tryParse(json['pd_discount_amount'] ?? '0') ?? 0.0,
    );
  }
}




class Item {
  final String itemName;
  final int quantity;
  final double price;
  final List<String> extras; // Assuming extras are a list of strings
  final String notes;

  Item({
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.extras,
    required this.notes,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price'] ?? '0') ?? 0.0,
      extras: (json['extras'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      notes: json['notes'] ?? '',
    );
  }
}



class OrderResponse {
  final Map<String, Order> orders;
  final bool success;
  final String message;

  OrderResponse({
    required this.orders,
    required this.success,
    required this.message,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    final orders = <String, Order>{};
    if (json['tabledetails'] != null) {
      json['tabledetails'].forEach((key, value) {
        orders[key] = Order.fromJson(value);
      });
    }
    return OrderResponse(
      orders: orders,
      success: json['success'] == 1,
      message: json['message'] ?? '',
    );
  }
}

class OrderDetail {
  final String itemName;
  final int quantity;
  final double price;
  final List<String> extras; // Assuming extras is a list of strings
  final String notes;

  OrderDetail({
    required this.itemName,
    required this.quantity,
    required this.price,
    this.extras = const [],
    this.notes = '',
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      itemName: json['pd_name'] ?? '',
      quantity: int.tryParse(json['od_qty']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['pd_order_price']?.toString() ?? '0') ?? 0.0,
      extras: json['extras'] != null
          ? List<String>.from(json['extras'])
          : const [],
      notes: json['notes'] ?? '',
    );
  }
}

class OrderDetailsResponse {
  final Map<String, OrderDetail> items;
  final bool success;
  final String message;

  OrderDetailsResponse({
    required this.items,
    required this.success,
    required this.message,
  });

  factory OrderDetailsResponse.fromJson(Map<String, dynamic> json) {
    final items = <String, OrderDetail>{};

    if (json['tableitemdetails'] != null) {
      json['tableitemdetails'].forEach((key, value) {
        items[key] = OrderDetail.fromJson(value);
      });
    }

    return OrderDetailsResponse(
      items: items,
      success: json['success'] == 1,
      message: json['message'] ?? '',
    );
  }
}