import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/services/demo_data_seeder.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(logStatements: false));
  });

  tearDown(() async {
    await db.close();
  });

  test('purgeAllData completes without Foreign Key constraint error', () async {
    // 1. Seed demo data (creates sales, credit payments, sale items, customers, etc.)
    await DemoDataSeeder.seedDatabase(db);

    // 2. Execute purgeAllData
    await expectLater(db.purgeAllData(), completes);

    // 3. Verify database tables are empty
    final sales = await db.select(db.sales).get();
    final creditPayments = await db.select(db.creditPayments).get();
    final saleItems = await db.select(db.saleItems).get();

    expect(sales, isEmpty);
    expect(creditPayments, isEmpty);
    expect(saleItems, isEmpty);
  });
}
