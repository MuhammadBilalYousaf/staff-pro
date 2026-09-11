import 'package:intl/intl.dart';
import 'package:staffpro/core/constants/app_constants.dart';

class Formatters {
  Formatters._();

  static final _money = NumberFormat('#,##0');
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateShort = DateFormat('dd MMM');
  static final _time = DateFormat('hh:mm a');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _day = DateFormat('EEE, dd MMM');
  static final _month = DateFormat('MMMM yyyy');

  static String money(num value) =>
      '${AppConstants.currencySymbol} ${_money.format(value.round())}';

  static String moneyRaw(num value) => _money.format(value.round());

  static String date(DateTime value) => _date.format(value);

  static String dateShort(DateTime value) => _dateShort.format(value);

  static String time(DateTime value) => _time.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String day(DateTime value) => _day.format(value);

  static String month(DateTime value) => _month.format(value);

  static String relative(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays < 7) {
      return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    }
    return date(value);
  }

  static String duration(int? minutes) {
    if (minutes == null) return '--:--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String trend(num current, num previous) {
    if (previous == 0) {
      return current == 0 ? '0%' : '+100%';
    }
    final change = ((current - previous) / previous) * 100;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(0)}%';
  }
}
