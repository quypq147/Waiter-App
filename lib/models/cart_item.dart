// lib/models/cart_item.dart
import 'menu_item_model.dart';

class CartItem {
  final String id;
  final MenuItemModel item;
  final int qty;
  final String? note;

  CartItem({
    required this.id,
    required this.item,
    required this.qty,
    this.note,
  });

  // Thêm hàm này:
  CartItem copyWith({
    String? id,
    MenuItemModel? item,
    int? qty,
    String? note,
  }) {
    return CartItem(
      id: id ?? this.id,
      item: item ?? this.item,
      qty: qty ?? this.qty,
      note: note ?? this.note,
    );
  }
}



