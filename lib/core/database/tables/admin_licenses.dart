import 'package:drift/drift.dart';

import 'admin_clients.dart';

@DataClassName('AdminLicense')
class AdminLicenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get adminClientId => integer().references(AdminClients, #id)();
  
  TextColumn get licenseKey => text().unique()();
  TextColumn get licenseType => text()(); // 'annual', 'lifetime'
  
  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()(); // Nullable for lifetime (though technically it's 9999-12-31, but good practice)
  
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'expired', 'cancelled'
  TextColumn get notes => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
