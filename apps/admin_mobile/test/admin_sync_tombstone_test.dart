import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nmashop_admin_mobile/core/repositories/admin_repository.dart';
import 'package:nmashop_admin_mobile/core/services/admin_sync_service.dart';
import 'package:nmashop_admin_mobile/core/models/client_model.dart';
import 'package:nmashop_admin_mobile/core/models/license_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Deleting client/license tombstones hardwareId in deletedLicenses, and new activation clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = AdminRepository(prefs);
    final service = AdminSyncService(repo);

    // 1. Initial state: save client & license
    final client = ClientModel(
      id: 'c1',
      storeName: 'Boutique Old',
      ownerName: 'Test',
      phone: '123',
      city: 'Conakry',
      hardwareId: 'NMA-7C41-E819-EDEB',
      createdAt: DateTime.now(),
    );
    final license = LicenseRecord(
      id: 'l1',
      clientId: 'c1',
      clientName: 'Boutique Old',
      hardwareId: 'NMA-7C41-E819-EDEB',
      licenseKey: 'TRIAL-OLD',
      type: AdminLicenseType.trial,
      amountPaid: 0.0,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await repo.saveClient(client);
    await repo.saveLicense(license);

    expect(repo.getClients().length, equals(1));
    expect(repo.getLicenses().length, equals(1));

    // 2. User deletes client/license in Admin Mobile
    await repo.deleteLicense('l1');
    await repo.deleteClient('c1');

    expect(repo.getClients().length, equals(0));
    expect(repo.getLicenses().length, equals(0));
    expect(repo.getDeletedClientHwIds(), contains('NMA-7C41-E819-EDEB'));
    expect(repo.getDeletedLicenseKeys(), contains('NMA-7C41-E819-EDEB'));

    // 3. New activation payload from Neon arrives (user reset PC app & created Boutique Test)
    final newPayload = {
      'businessName': 'Boutique Test',
      'ownerName': 'Hassimiou Thioye',
      'phone': '624193069',
      'address': 'Linux',
      'hardwareId': 'NMA-7C41-E819-EDEB',
      'licenseKey': 'TRIAL-7C41E819EDEB',
      'activatedAt': DateTime.now().toIso8601String(),
      'expiryDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'isActive': true,
    };

    await service.importManualPayload(jsonEncode(newPayload));

    // Verify tombstones are cleared
    expect(repo.getDeletedClientHwIds(), isNot(contains('NMA-7C41-E819-EDEB')));
    expect(repo.getDeletedLicenseKeys(), isNot(contains('NMA-7C41-E819-EDEB')));

    // Verify client and license are restored & visible!
    final clients = repo.getClients();
    final licenses = repo.getLicenses();
    expect(clients.length, equals(1));
    expect(clients.first.storeName, equals('Boutique Test'));
    expect(licenses.length, equals(1));
    expect(licenses.first.type, equals(AdminLicenseType.trial));
    expect(licenses.first.clientName, equals('Boutique Test'));
  });
}
