import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  final String id; // doc id nếu bạn lưu items là subcollection; nếu lưu mảng thì có thể bỏ
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String? note;
  final DateTime? createdAt;

  const OrderItemModel({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.note,
    this.createdAt,
  });

  double get lineTotal => price * quantity;

  factory OrderItemModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final created = map['createdAt'];
    return OrderItemModel(
      id: id ?? (map['id']?.toString() ?? ''),
      menuItemId: map['menuItemId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] as num?)?.toDouble() ?? 0,
      quantity: (map['qty'] as int?) ?? (map['quantity'] as int?) ?? 0,
      note: map['note'] as String?,
      createdAt: created is Timestamp ? created.toDate() : (created is DateTime ? created : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'qty': quantity,
      'note': note,
      'lineTotal': lineTotal,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  OrderItemModel copyWith({int? quantity, String? note}) {
    return OrderItemModel(
      id: id,
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}

