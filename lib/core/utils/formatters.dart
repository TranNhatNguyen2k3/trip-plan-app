import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final _vndFormat = NumberFormat('#,###', 'vi_VN');

String formatCurrency(
  int amount, {
  String currency = AppConstants.defaultCurrency,
  bool signed = false,
}) {
  final abs = amount.abs();
  final formatted = switch (currency) {
    'VND' => '${_vndFormat.format(abs)} ₫',
    _ => NumberFormat.currency(symbol: currency).format(abs),
  };
  if (!signed) return formatted;
  if (amount > 0) return '+$formatted';
  if (amount < 0) return '-$formatted';
  return formatted;
}

String formatCompactCurrency(int amount, {String currency = AppConstants.defaultCurrency}) {
  if (currency != 'VND') return formatCurrency(amount, currency: currency);
  if (amount.abs() >= 1000000) {
    final millions = amount / 1000000;
    final text = millions == millions.roundToDouble()
        ? millions.toInt().toString()
        : millions.toStringAsFixed(2);
    return '${text}M ₫';
  }
  return formatCurrency(amount, currency: currency);
}

String formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

String formatDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  if (start != null && end != null) {
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }
  return formatDate(start ?? end!);
}

String formatTime(DateTime date) => DateFormat('h:mm a').format(date);

String greetingForNow([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
