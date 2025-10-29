import 'package:meta/meta.dart';

enum TableState { vacant, occupied, billed, cleaning, reserved }

@immutable
class TableModel {
  final String id;
  final String name;
  final int capacity;
  final TableState state;
  final String? currentOrderId;
  final bool isAvailable; // giữ để tương thích UI cũ nếu bạn đã dùng

  const TableModel({
    required this.id,
    required this.name,
    required this.capacity,
    required this.state,
    this.currentOrderId,
    this.isAvailable = true,
  });

  factory TableModel.fromMap(String id, Map<String, dynamic> data) {
  // state có thể là string ('vacant',...) hoặc kiểu khác => ép về string-lower
  final raw = (data['state']?.toString() ?? 'vacant').toLowerCase();

  TableState parseState(String s) {
    switch (s) {
      case 'occupied': return TableState.occupied;
      case 'billed':   return TableState.billed;
      case 'cleaning': return TableState.cleaning;
      case 'reserved': return TableState.reserved;
      default:         return TableState.vacant;
    }
  }

  // capacity có thể là int/double/chuỗi => ép an toàn về int
  int toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  final state = parseState(raw);

  return TableModel(
    id: id,
    name: (data['name']?.toString() ?? ''),
    capacity: toInt(data['capacity']),
    state: state,
    currentOrderId: data['currentOrderId']?.toString(),
    isAvailable: state == TableState.vacant,
  );
}


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'state': state.name,
      'currentOrderId': currentOrderId,
    };
  }
}





