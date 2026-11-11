enum ReportPeriod { daily, weekly }

/// Aggregated Sales & Performance Report Model
class PosReportModel {
  final ReportPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalOrders;
  final double totalRevenue; // Total Business: Net Sales - Total Discount + Total Tax
  final double totalNetSales; // All items net sales
  final double totalDiscount; // Total discount amount
  final double totalTax; // Total tax collected
  final double totalDeliveryCharge; // Total delivery charges collected
  final double totalCashBusiness; // Cash net + Cash tax - Cash discount
  final double totalCardBusiness; // Card net + Card tax - Card discount
  final double totalUpiBusiness; // UPI net + UPI tax - UPI discount
  final double totalFoodBusiness;
  final double totalDrinksBusiness;
  final List<CompletedOrderSummary> completedOrders;
  final List<ItemSalesSummary> itemSales;

  const PosReportModel({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalOrders,
    required this.totalRevenue,
    this.totalNetSales = 0.0,
    this.totalDiscount = 0.0,
    this.totalTax = 0.0,
    this.totalDeliveryCharge = 0.0,
    required this.totalCashBusiness,
    required this.totalCardBusiness,
    required this.totalUpiBusiness,
    required this.totalFoodBusiness,
    required this.totalDrinksBusiness,
    this.completedOrders = const [],
    this.itemSales = const [],
  });

  double get totalCash => totalCashBusiness;
  double get totalCard => totalCardBusiness;
  double get totalUpi => totalUpiBusiness;

  /// Cash percentage of total revenue
  double get cashPercentage =>
      totalRevenue > 0 ? (totalCashBusiness / totalRevenue) * 100 : 0.0;

  /// Card percentage of total revenue
  double get cardPercentage =>
      totalRevenue > 0 ? (totalCardBusiness / totalRevenue) * 100 : 0.0;

  /// UPI percentage of total revenue
  double get upiPercentage =>
      totalRevenue > 0 ? (totalUpiBusiness / totalRevenue) * 100 : 0.0;

  /// Food percentage of total item business
  double get foodPercentage {
    final catTotal = totalFoodBusiness + totalDrinksBusiness;
    return catTotal > 0 ? (totalFoodBusiness / catTotal) * 100 : 0.0;
  }

  /// Drinks percentage of total item business
  double get drinksPercentage {
    final catTotal = totalFoodBusiness + totalDrinksBusiness;
    return catTotal > 0 ? (totalDrinksBusiness / catTotal) * 100 : 0.0;
  }

  /// Average Order Value (AOV)
  double get averageOrderValue =>
      totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
}

/// Item-wise sales record for daily reports
class ItemSalesSummary {
  final int itemId;
  final String itemName;
  final String categoryName;
  final int quantitySold;
  final double totalRevenue;
  final String itemType;

  const ItemSalesSummary({
    this.itemId = 0,
    required this.itemName,
    required this.categoryName,
    required this.quantitySold,
    required this.totalRevenue,
    this.itemType = 'veg',
  });
}

/// Line item summary of a single completed/settled order
class CompletedOrderSummary {
  final int orderId;
  final String orderType; // 'sitdown' or 'takeaway'
  final int tableNumber;
  final String customerName;
  final String customerPhone;
  final String paymentType; // 'cash', 'card', 'upi_qr'
  final double totalAmount; // Net total + Delivery charge - Discount + Tax total
  final double netAmount; // Net bill amount (items subtotal)
  final double discountAmount; // Order discount amount
  final double taxAmount; // Total tax amount
  final double deliveryCharge; // Order delivery charge
  final String? orderComments; // Order comments
  final double foodAmount;
  final double drinksAmount;
  final DateTime orderDate;
  final DateTime settledAt;
  final int itemCount;

  const CompletedOrderSummary({
    required this.orderId,
    required this.orderType,
    required this.tableNumber,
    required this.customerName,
    this.customerPhone = '',
    required this.paymentType,
    required this.totalAmount,
    this.netAmount = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.orderComments,
    required this.foodAmount,
    required this.drinksAmount,
    required this.orderDate,
    required this.settledAt,
    required this.itemCount,
  });

  bool get isSitDown => orderType == 'sitdown';

  String get paymentDisplay {
    switch (paymentType.toLowerCase()) {
      case 'card':
        return 'Card';
      case 'upi_qr':
      case 'upi':
        return 'UPI QR';
      default:
        return 'Cash';
    }
  }
}
