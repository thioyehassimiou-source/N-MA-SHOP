class ShopInfo {
  final String id;
  final String name;
  final String currency;
  final DateTime? lastSyncAt;

  ShopInfo({
    required this.id,
    required this.name,
    required this.currency,
    this.lastSyncAt,
  });

  factory ShopInfo.fromJson(Map<String, dynamic> json) {
    return ShopInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Boutique',
      currency: json['currency'] ?? 'GNF',
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.tryParse(json['lastSyncAt']) : null,
    );
  }
}

class DayKpis {
  final int totalSales;
  final int totalProfit;
  final int salesCount;
  final int cashCollected;
  final int momoCollected;
  final int creditIssued;

  DayKpis({
    this.totalSales = 0,
    this.totalProfit = 0,
    this.salesCount = 0,
    this.cashCollected = 0,
    this.momoCollected = 0,
    this.creditIssued = 0,
  });

  factory DayKpis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DayKpis();
    return DayKpis(
      totalSales: json['totalSales'] ?? 0,
      totalProfit: json['totalProfit'] ?? 0,
      salesCount: json['salesCount'] ?? 0,
      cashCollected: json['cashCollected'] ?? 0,
      momoCollected: json['momoCollected'] ?? 0,
      creditIssued: json['creditIssued'] ?? 0,
    );
  }
}

class StockSummary {
  final int lowStockCount;
  final int outOfStockCount;

  StockSummary({this.lowStockCount = 0, this.outOfStockCount = 0});

  factory StockSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StockSummary();
    return StockSummary(
      lowStockCount: json['lowStockCount'] ?? 0,
      outOfStockCount: json['outOfStockCount'] ?? 0,
    );
  }
}

class ReceivablesSummary {
  final int totalAmount;
  final int debtorsCount;

  ReceivablesSummary({this.totalAmount = 0, this.debtorsCount = 0});

  factory ReceivablesSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReceivablesSummary();
    return ReceivablesSummary(
      totalAmount: json['totalAmount'] ?? 0,
      debtorsCount: json['debtorsCount'] ?? 0,
    );
  }
}

class AlertItem {
  final String id;
  final String type;
  final String severity; // info, warning, critical
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      severity: json['severity'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}

class DashboardData {
  final ShopInfo shop;
  final DayKpis today;
  final DayKpis yesterday;
  final StockSummary stock;
  final ReceivablesSummary receivables;
  final int unreadAlertsCount;
  final List<AlertItem> recentAlerts;
  final DateTime serverTime;
  final DateTime localFetchTime;

  DashboardData({
    required this.shop,
    required this.today,
    required this.yesterday,
    required this.stock,
    required this.receivables,
    required this.unreadAlertsCount,
    required this.recentAlerts,
    required this.serverTime,
    required this.localFetchTime,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final alertsObj = json['alerts'];
    List<AlertItem> recentList = [];
    int unreadCount = 0;

    if (alertsObj is Map<String, dynamic>) {
      unreadCount = alertsObj['unreadCount'] ?? json['unreadAlertsCount'] ?? 0;
      final list = alertsObj['recent'] as List?;
      if (list != null) {
        recentList = list.map((a) => AlertItem.fromJson(a as Map<String, dynamic>)).toList();
      }
    } else if (json['recentAlerts'] is List) {
      unreadCount = json['unreadAlertsCount'] ?? 0;
      recentList = (json['recentAlerts'] as List)
          .map((a) => AlertItem.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    return DashboardData(
      shop: ShopInfo.fromJson(json['shop'] ?? {}),
      today: DayKpis.fromJson(json['today']),
      yesterday: DayKpis.fromJson(json['yesterday']),
      stock: StockSummary.fromJson(json['stock']),
      receivables: ReceivablesSummary.fromJson(json['receivables']),
      unreadAlertsCount: unreadCount,
      recentAlerts: recentList,
      serverTime: json['serverTime'] != null ? DateTime.tryParse(json['serverTime']) ?? DateTime.now() : DateTime.now(),
      localFetchTime: DateTime.now(),
    );
  }
}
