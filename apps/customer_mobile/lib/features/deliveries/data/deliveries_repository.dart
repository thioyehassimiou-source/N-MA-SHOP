import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/mobile_database.dart';

/// Type de véhicule du livreur
enum MobileVehicleType {
  moto,
  voiture,
  camionnette,
  autre,
}

extension MobileVehicleTypeX on MobileVehicleType {
  String get label {
    switch (this) {
      case MobileVehicleType.moto:
        return 'Moto';
      case MobileVehicleType.voiture:
        return 'Voiture';
      case MobileVehicleType.camionnette:
        return 'Camionnette';
      case MobileVehicleType.autre:
        return 'Autre / À pied';
    }
  }

  String get iconName {
    switch (this) {
      case MobileVehicleType.moto:
        return '🛵';
      case MobileVehicleType.voiture:
        return '🚗';
      case MobileVehicleType.camionnette:
        return '🚐';
      case MobileVehicleType.autre:
        return '🚶';
    }
  }
}

/// Statut de la livraison
enum MobileDeliveryStatus {
  pending, // À expédier / En attente
  transit, // En cours de livraison
  delivered, // Livré avec succès
  failed, // Échec / Retour
}

extension MobileDeliveryStatusX on MobileDeliveryStatus {
  String get label {
    switch (this) {
      case MobileDeliveryStatus.pending:
        return 'À expédier';
      case MobileDeliveryStatus.transit:
        return 'En transit';
      case MobileDeliveryStatus.delivered:
        return 'Livrée';
      case MobileDeliveryStatus.failed:
        return 'Échec / Retour';
    }
  }
}

/// Modèle Coursier / Livreur
class MobileCourier {
  final String id;
  final String name;
  final String phone;
  final MobileVehicleType vehicleType;
  final bool isActive;
  final DateTime createdAt;

  const MobileCourier({
    required this.id,
    required this.name,
    this.phone = '',
    this.vehicleType = MobileVehicleType.moto,
    this.isActive = true,
    required this.createdAt,
  });
}

/// Modèle Livraison / Colis
class MobileDelivery {
  final String id;
  final String saleReference;
  final String courierId;
  final String courierName;
  final String courierPhone;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final MobileDeliveryStatus status;
  final int deliveryFee;
  final int amountToCollect;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? note;

  const MobileDelivery({
    required this.id,
    required this.saleReference,
    required this.courierId,
    required this.courierName,
    this.courierPhone = '',
    required this.customerName,
    this.customerPhone = '',
    required this.deliveryAddress,
    this.status = MobileDeliveryStatus.pending,
    this.deliveryFee = 0,
    this.amountToCollect = 0,
    required this.assignedAt,
    this.completedAt,
    this.note,
  });
}

final deliveriesRepositoryProvider = Provider<DeliveriesRepository>((ref) {
  final db = ref.watch(mobileDatabaseProvider);
  return DeliveriesRepository(db);
});

class DeliveriesRepository {
  final MobileDatabase _db;
  bool _initialized = false;

  DeliveriesRepository(this._db);

  Future<void> _ensureTables() async {
    if (_initialized) return;

    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS mobile_couriers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        vehicle_type INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS mobile_deliveries (
        id TEXT PRIMARY KEY,
        sale_reference TEXT NOT NULL,
        courier_id TEXT NOT NULL,
        courier_name TEXT NOT NULL,
        courier_phone TEXT,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        delivery_address TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        delivery_fee INTEGER NOT NULL DEFAULT 0,
        amount_to_collect INTEGER NOT NULL DEFAULT 0,
        assigned_at TEXT NOT NULL,
        completed_at TEXT,
        note TEXT
      );
    ''');

    _initialized = true;
  }

  // ── COURSIERS ──

  Future<List<MobileCourier>> getCouriers() async {
    await _ensureTables();
    final rows = await _db.customSelect(
      'SELECT * FROM mobile_couriers ORDER BY name ASC',
    ).get();

    return rows.map((r) {
      final vIndex = r.read<int>('vehicle_type');
      final vehicle = (vIndex >= 0 && vIndex < MobileVehicleType.values.length)
          ? MobileVehicleType.values[vIndex]
          : MobileVehicleType.moto;

      return MobileCourier(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        phone: r.read<String?>('phone') ?? '',
        vehicleType: vehicle,
        isActive: (r.read<int>('is_active')) == 1,
        createdAt: DateTime.tryParse(r.read<String>('created_at')) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> addCourier({
    required String name,
    required String phone,
    required MobileVehicleType vehicleType,
  }) async {
    await _ensureTables();
    final now = DateTime.now();
    final id = 'cour-${now.millisecondsSinceEpoch}';

    await _db.customStatement(
      '''
      INSERT INTO mobile_couriers (id, name, phone, vehicle_type, is_active, created_at)
      VALUES (?, ?, ?, ?, 1, ?);
      ''',
      [id, name, phone, vehicleType.index, now.toIso8601String()],
    );
  }

  Future<void> toggleCourierActive(String id, bool active) async {
    await _ensureTables();
    await _db.customStatement(
      'UPDATE mobile_couriers SET is_active = ? WHERE id = ?;',
      [active ? 1 : 0, id],
    );
  }

  Future<void> deleteCourier(String id) async {
    await _ensureTables();
    await _db.customStatement('DELETE FROM mobile_couriers WHERE id = ?;', [id]);
  }

  // ── LIVRAISONS ──

  Future<List<MobileDelivery>> getDeliveries() async {
    await _ensureTables();
    final rows = await _db.customSelect(
      'SELECT * FROM mobile_deliveries ORDER BY assigned_at DESC',
    ).get();

    return rows.map((r) {
      final sIndex = r.read<int>('status');
      final status = (sIndex >= 0 && sIndex < MobileDeliveryStatus.values.length)
          ? MobileDeliveryStatus.values[sIndex]
          : MobileDeliveryStatus.pending;

      final compStr = r.read<String?>('completed_at');

      return MobileDelivery(
        id: r.read<String>('id'),
        saleReference: r.read<String>('sale_reference'),
        courierId: r.read<String>('courier_id'),
        courierName: r.read<String>('courier_name'),
        courierPhone: r.read<String?>('courier_phone') ?? '',
        customerName: r.read<String>('customer_name'),
        customerPhone: r.read<String?>('customer_phone') ?? '',
        deliveryAddress: r.read<String>('delivery_address'),
        status: status,
        deliveryFee: r.read<int>('delivery_fee'),
        amountToCollect: r.read<int>('amount_to_collect'),
        assignedAt: DateTime.tryParse(r.read<String>('assigned_at')) ?? DateTime.now(),
        completedAt: compStr != null ? DateTime.tryParse(compStr) : null,
        note: r.read<String?>('note'),
      );
    }).toList();
  }

  Future<void> createDelivery({
    required String saleReference,
    required String courierId,
    required String courierName,
    required String courierPhone,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required int deliveryFee,
    required int amountToCollect,
    String? note,
  }) async {
    await _ensureTables();
    final now = DateTime.now();
    final id = 'deliv-${now.millisecondsSinceEpoch}';

    await _db.customStatement(
      '''
      INSERT INTO mobile_deliveries (
        id, sale_reference, courier_id, courier_name, courier_phone,
        customer_name, customer_phone, delivery_address, status,
        delivery_fee, amount_to_collect, assigned_at, note
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?);
      ''',
      [
        id,
        saleReference,
        courierId,
        courierName,
        courierPhone,
        customerName,
        customerPhone,
        deliveryAddress,
        deliveryFee,
        amountToCollect,
        now.toIso8601String(),
        note ?? '',
      ],
    );
  }

  Future<void> updateDeliveryStatus(String id, MobileDeliveryStatus newStatus) async {
    await _ensureTables();
    final now = DateTime.now().toIso8601String();
    final completed = (newStatus == MobileDeliveryStatus.delivered || newStatus == MobileDeliveryStatus.failed) ? now : null;

    await _db.customStatement(
      'UPDATE mobile_deliveries SET status = ?, completed_at = ? WHERE id = ?;',
      [newStatus.index, completed, id],
    );
  }

  Future<void> deleteDelivery(String id) async {
    await _ensureTables();
    await _db.customStatement('DELETE FROM mobile_deliveries WHERE id = ?;', [id]);
  }
}

