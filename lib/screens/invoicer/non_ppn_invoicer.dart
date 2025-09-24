import 'package:flutter/material.dart';

class NonPpnInvoicer extends StatelessWidget {
  const NonPpnInvoicer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        "Fitur Non-PPN akan segera hadir",
        style: theme.textTheme.titleMedium!.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}
