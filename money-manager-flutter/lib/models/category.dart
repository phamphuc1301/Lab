import 'package:flutter/material.dart';

enum TxKind { expense, income }

/// Display names are localized: see `categoryName` in lib/l10n.
enum TxCategory {
  food(Icons.restaurant, Colors.orange),
  groceries(Icons.shopping_cart, Colors.green),
  transport(Icons.directions_car, Colors.blue),
  shopping(Icons.shopping_bag, Colors.pink),
  bills(Icons.bolt, Colors.amber),
  housing(Icons.home, Colors.brown),
  health(Icons.medical_services, Colors.red),
  entertainment(Icons.movie, Colors.purple),
  education(Icons.menu_book, Colors.indigo),
  travel(Icons.flight, Colors.cyan),
  other(Icons.category, Colors.blueGrey),
  salary(Icons.payments, Colors.teal, isIncome: true),
  bonus(Icons.card_giftcard, Colors.teal, isIncome: true),
  investment(Icons.trending_up, Colors.teal, isIncome: true),
  otherIncome(Icons.add_circle, Colors.teal, isIncome: true);

  const TxCategory(this.icon, this.color, {this.isIncome = false});

  final IconData icon;
  final Color color;
  final bool isIncome;

  static List<TxCategory> forKind(TxKind kind) =>
      values.where((c) => c.isIncome == (kind == TxKind.income)).toList();

  static TxCategory? byName(String name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
