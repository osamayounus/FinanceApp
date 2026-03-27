import 'package:financeapp/models/expense_model.dart';
import 'package:flutter/material.dart';

/// A bill category definition: name, icon, and accent color.
class BillCat {
  final String name;
  final IconData icon;
  final Color color;
  const BillCat(this.name, this.icon, this.color);
}

/// Predefined bill categories in display order.
/// Colors are intentional per-category palette values, not theme colors.
const kBillCats = [
  BillCat('Housing',       Icons.home_rounded,            Color(0xFF7C4DFF)),
  BillCat('Utilities',     Icons.bolt_rounded,            Color(0xFFFFB300)),
  BillCat('Subscriptions', Icons.play_circle_rounded,     Color(0xFFE91E63)),
  BillCat('Transport',     Icons.directions_car_rounded,  Color(0xFF2979FF)),
  BillCat('Health',        Icons.favorite_rounded,        Color(0xFFE53935)),
  BillCat('Education',     Icons.school_rounded,          Color(0xFF00BCD4)),
  BillCat('Food',          Icons.restaurant_rounded,      Color(0xFFFF6D00)),
  BillCat('Other',         Icons.category_rounded,        Color(0xFF78909C)),
];

/// Returns the [BillCat] matching [name], falling back to 'Other' if not found.
BillCat catFor(String name) =>
    kBillCats.firstWhere((c) => c.name == name, orElse: () => kBillCats.last);

/// Returns the display category name for [e], defaulting to 'Other' when unset.
String displayCat(ExpenseModel e) =>
    e.category.isEmpty ? 'Other' : e.category;
