import 'menu_item_model.dart';

enum OrderType {
  sitDown,
  parcel,
}

enum TableOrderStatus {
  closed, // Green: Free / Available
  open,   // Red: In-progress / Occupied / Active order
}

class TableModel {
  final int id;
  final String name; // e.g. "Table 1", "Table 8", "Table 10" or Customer Name for Parcel
  final int tableNumber;
  final TableOrderStatus status;
  final OrderType orderType;
  final String? customerName;
  final String? customerPhone;
  final double currentTotal;
  final double discountAmount;
  final double discountPercent;
  final double deliveryCharge;
  final String? orderComments;
  final int itemCount;
  final DateTime? seatedAt;
  final List<CartItemModel> activeCart;
  final int? activeOrderId;

  const TableModel({
    required this.id,
    required this.name,
    required this.tableNumber,
    required this.status,
    this.orderType = OrderType.sitDown,
    this.customerName,
    this.customerPhone,
    this.currentTotal = 0.0,
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
    this.deliveryCharge = 0.0,
    this.orderComments,
    this.itemCount = 0,
    this.seatedAt,
    this.activeCart = const [],
    this.activeOrderId,
  });

  bool get isOpen => status == TableOrderStatus.open;
  bool get isClosed => status == TableOrderStatus.closed;
  bool get isParcel => orderType == OrderType.parcel;
  bool get isDiscountPercent => discountPercent > 0.0;

  /// Net item sum (without tax)
  double get netTotal => activeCart.isNotEmpty
      ? activeCart.fold(0.0, (sum, i) => sum + i.totalPrice)
      : currentTotal;

  /// Effective order discount amount (capped at netTotal)
  double get effectiveDiscount => discountAmount.clamp(0.0, netTotal);

  /// Total tax calculated from each item
  double get taxTotal => activeCart.isNotEmpty
      ? activeCart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)))
      : 0.0;

  /// Total Bill Amount = Net items total + Tax total + Delivery Charge - Order Discount
  double get totalWithTax => ((netTotal - effectiveDiscount) + taxTotal + deliveryCharge).clamp(0.0, double.infinity);
  double get payableTotal => totalWithTax;

  TableModel copyWith({
    int? id,
    String? name,
    int? tableNumber,
    TableOrderStatus? status,
    OrderType? orderType,
    String? customerName,
    String? customerPhone,
    double? currentTotal,
    double? discountAmount,
    double? discountPercent,
    double? deliveryCharge,
    String? orderComments,
    int? itemCount,
    DateTime? seatedAt,
    List<CartItemModel>? activeCart,
    int? activeOrderId,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      currentTotal: currentTotal ?? this.currentTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      orderComments: orderComments ?? this.orderComments,
      itemCount: itemCount ?? this.itemCount,
      seatedAt: seatedAt ?? this.seatedAt,
      activeCart: activeCart ?? this.activeCart,
      activeOrderId: activeOrderId ?? this.activeOrderId,
    );
  }
}
