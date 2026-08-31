import 'package:intl/intl.dart';

/// Formatage des montants en francs guinéens (GNF).
///
/// Le GNF ne comporte pas de subdivision usuelle : les montants sont des
/// entiers, avec séparateur de milliers par espace (convention locale/FR).
final NumberFormat _gnf = NumberFormat.decimalPattern('fr');

String formatGnf(num amount) => '${_gnf.format(amount)} GNF';

/// Formatage court sans suffixe (pour tableaux denses).
String formatAmount(num amount) => _gnf.format(amount);

/// Formatage des montants pour les cartes de synthèse (montants complets lisibles sans K/M/Md).
String formatGnfCompact(num amount) {
  final abs = amount.abs();
  final sign = amount < 0 ? '-' : '';
  return '$sign${_gnf.format(abs)} GNF';
}

/// Formatage d'une quantité (toujours entière depuis le retrait du vrac).
String formatQuantity(num qty) => qty.toInt().toString();

final DateFormat _date = DateFormat('dd/MM/yyyy', 'fr');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'fr');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);

final DateFormat _longDate = DateFormat('EEEE d MMMM', 'fr');
final DateFormat _time = DateFormat('HH:mm', 'fr');

/// Date longue en français : « lundi 14 juin ».
String formatLongDate(DateTime d) => _longDate.format(d);

/// Heure seule : « 10:45 ».
String formatTime(DateTime d) => _time.format(d);

/// Repère temporel court pour les listes : « 10:45 » si aujourd'hui,
/// « Hier », sinon la date.
String formatRelativeDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return _time.format(d);
  if (diff == 1) return 'Hier';
  return _date.format(d);
}
