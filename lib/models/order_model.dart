import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

enum OrderStatus { open, billed, paid, voided }

@immutable
class OrderModel {
  final String id;
  final String tableId;
  final String waiterId;
  final OrderStatus status;

  final int itemsCount;
  final int covers;

  final double subtotal;
  final double discount;
  final double serviceCharge;
  final double tax;
  final double total;

  final DateTime? openedAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  const OrderModel({
    required this.id,
    required this.tableId,
    required this.waiterId,
    required this.status,
    this.itemsCount = 0,
    this.covers = 0,
    this.subtotal = 0,
    this.discount = 0,
    this.serviceCharge = 0,
    this.tax = 0,
    this.total = 0,
    this.openedAt,
    this.updatedAt,
    this.closedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    DateTime? ts(v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    double d(v) => v == null ? 0 : (v is int ? v.toDouble() : (v as num).toDouble());

    return OrderModel(
      id: map['id']?.toString() ?? '',
      tableId: map['tableId']?.toString() ?? '',
      waiterId: map['waiterId']?.toString() ?? '',
      status: _parseStatus(map['status']?.toString()),
      itemsCount: (map['itemsCount'] as int?) ?? 0,
      covers: (map['covers'] as int?) ?? 0,
      subtotal: d(map['subtotal']),
      discount: d(map['discount']),
      serviceCharge: d(map['serviceCharge']),
      tax: d(map['tax']),
      total: d(map['total']),
      openedAt: ts(map['openedAt']),
      updatedAt: ts(map['updatedAt']),
      closedAt: ts(map['closedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableId': tableId,
      'waiterId': waiterId,
      'status': _statusToString(status),
      'itemsCount': itemsCount,
      'covers': covers,
      'subtotal': subtotal,
      'discount': discount,
      'serviceCharge': serviceCharge,
      'tax': tax,
      'total': total,
      'openedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
    };
  }

  static OrderStatus _parseStatus(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open': return OrderStatus.open;
      case 'billed': return OrderStatus.billed;
      case 'paid': return OrderStatus.paid;
      case 'voided': return OrderStatus.voided;
      default: return OrderStatus.open;
    }
  }

  static String _statusToString(OrderStatus st) {
    switch (st) {
      case OrderStatus.open: return 'open';
      case OrderStatus.billed: return 'billed';
      case OrderStatus.paid: return 'paid';
      case OrderStatus.voided: return 'voided';
    }
  }

  OrderModel copyWith({
    OrderStatus? status,
    int? itemsCount,
    int? covers,
    double? subtotal,
    double? discount,
    double? serviceCharge,
    double? tax,
    double? total,
    DateTime? openedAt,
    DateTime? updatedAt,
    DateTime? closedAt,
  }) {
    return OrderModel(
      id: id,
      tableId: tableId,
      waiterId: waiterId,
      status: status ?? this.status,
      itemsCount: itemsCount ?? this.itemsCount,
      covers: covers ?? this.covers,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      openedAt: openedAt ?? this.openedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}




