import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/users.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';

final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllUsers();
});

final equipeControllerProvider = NotifierProvider<EquipeController, void>(EquipeController.new);

class EquipeController extends Notifier<void> {
  @override
  void build() {}

  Future<void> createUser({
    required String fullName,
    required String password,
    required UserRole role,
    double commissionRate = 0.0,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.createUser(
      fullName: fullName,
      password: password,
      role: role,
      commissionRate: commissionRate,
    );
    ref.invalidate(usersListProvider);
  }

  Future<void> toggleStatus(String userId, bool isActive) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.toggleUserStatus(userId, isActive);
    ref.invalidate(usersListProvider);
  }

  Future<void> updateCommissionRate(String userId, double rate) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.updateCommissionRate(userId, rate);
    ref.invalidate(usersListProvider);
  }
}
