import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  static String formatCurrency(num amount, {String currency = 'GNF'}) {
    final formatted = _currencyFormat
        .format(amount)
        .replaceAll(',', ' ')
        .replaceAll('\u202f', ' ')
        .replaceAll('\u00a0', ' ');
    return '$formatted $currency';
  }

  static String formatCompactNumber(num number) {
    if (number >= 1000000) {
      final m = number / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    } else if (number >= 1000) {
      final k = number / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return number.toString();
  }

  static String formatRelativeTime(DateTime? time) {
    if (time == null) return 'Jamais';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 45) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Hier à ${DateFormat('HH:mm').format(time)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(time);
    }
  }

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
  }
}
