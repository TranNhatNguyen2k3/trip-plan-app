import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import '../utils/formatters.dart';

class AppCurrencyText extends StatelessWidget {
  const AppCurrencyText(
    this.amount, {
    super.key,
    this.currency = 'VND',
    this.signed = false,
    this.fontSize = 28,
    this.color,
  });

  final int amount;
  final String currency;
  final bool signed;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color resolved = color ?? scheme.onSurface;
    if (signed && color == null) {
      if (amount > 0) resolved = const Color(0xFF16A34A);
      if (amount < 0) resolved = scheme.error;
    }

    return Text(
      formatCurrency(amount, currency: currency, signed: signed),
      style: AppTypography.money(color: resolved, fontSize: fontSize),
      semanticsLabel: formatCurrency(amount, currency: currency, signed: signed),
    );
  }
}
