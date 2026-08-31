import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_model.dart';
import '../models/license_record.dart';
import '../repositories/admin_repository.dart';
import '../services/admin_sync_service.dart';

final sharedPreferencesProvider = Provider<dynamic>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AdminRepository(prefs);
});

final adminSyncServiceProvider = Provider<AdminSyncService>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminSyncService(repo);
});

// ── Auth Lock Provider ────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void authenticate() => state = true;
  void lock() => state = false;
  void logout() => state = false;
}

final isAuthenticatedProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

// ── Clients Notifier ──────────────────────────────────────────────────────────

class ClientsNotifier extends Notifier<List<ClientModel>> {
  @override
  List<ClientModel> build() {
    final repo = ref.watch(adminRepositoryProvider);
    return repo.getClients();
  }

  void refresh() {
    final repo = ref.read(adminRepositoryProvider);
    state = repo.getClients();
  }

  Future<void> addOrUpdateClient(ClientModel client) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.saveClient(client);
    state = repo.getClients();
  }

  Future<void> deleteClient(String id) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.deleteClient(id);
    state = repo.getClients();
  }

  Future<void> removeClient(String id) => deleteClient(id);
}

final clientsProvider = NotifierProvider<ClientsNotifier, List<ClientModel>>(ClientsNotifier.new);

// ── Licenses History Notifier ─────────────────────────────────────────────────

class LicensesNotifier extends Notifier<List<LicenseRecord>> {
  @override
  List<LicenseRecord> build() {
    final repo = ref.watch(adminRepositoryProvider);
    return repo.getLicenses();
  }

  void refresh() {
    final repo = ref.read(adminRepositoryProvider);
    state = repo.getLicenses();
  }

  Future<void> addLicense(LicenseRecord record) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.saveLicense(record);
    state = repo.getLicenses();
  }

  Future<void> updateLicense(LicenseRecord record) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.saveLicense(record);
    state = repo.getLicenses();
  }

  Future<void> removeLicense(String id) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.deleteLicense(id);
    state = repo.getLicenses();
  }
}

final licensesProvider = NotifierProvider<LicensesNotifier, List<LicenseRecord>>(LicensesNotifier.new);
