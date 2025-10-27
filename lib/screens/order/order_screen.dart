import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/firestore_paths.dart';
import '../../data/app_repository.dart';
import '../../models/table_model.dart';
import '../../widgets/app_drawer.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    final table = repo.selectedTable;
    final orderId = repo.activeOrderId;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          (table == null || orderId == null)
              ? 'Đơn hàng'
              : 'Bàn ${table.name} • #${orderId.length >= 6 ? orderId.substring(0, 6) : orderId}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Thêm món',
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: (table == null || orderId == null)
                ? null
                : () => Navigator.pushReplacementNamed(context, '/menu'),
          ),
        ],
      ),
      body: (table == null || orderId == null)
          ? const Center(child: Text('Chưa có bàn hoặc chưa có order đang mở'))
          : _OrderDetail(orderId: orderId),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  final String orderId;
  const _OrderDetail({required this.orderId});

  @override
  Widget build(BuildContext context) {
    const rid = 'default_restaurant'; // TODO: lấy từ repo nếu có

    final orderRef =
        FirebaseFirestore.instance.collection(FP.orders(rid)).doc(orderId);

    final itemsRef = FirebaseFirestore.instance
        .collection(FP.orderItems(rid, orderId))
        .orderBy('createdAt', descending: false);

    return SafeArea(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: orderRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final od = snap.data!.data() ?? {};
              final status = (od['status'] ?? 'open') as String;
              final subtotal = (od['subtotal'] ?? 0).toDouble();
              final total = (od['total'] ?? 0).toDouble();
              final itemsCount = (od['itemsCount'] ?? 0) as int;

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusChip(status: status),
                    Text('Món: $itemsCount'),
                    Text('Tạm tính: ${_vnd(subtotal)}'),
                    Text('Tổng: ${_vnd(total)}'),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: itemsRef.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có món trong order'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final it = docs[i].data();
                    final name = (it['name'] ?? '') as String;
                    final price = (it['price'] ?? 0).toDouble();
                    final qty = (it['qty'] ?? 0) as int;
                    final note = (it['note'] ?? '') as String;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.restaurant)),
                        title: Text(name, overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          '${_vnd(price)} x $qty = ${_vnd(price * qty)}',
                          if (note.isNotEmpty) 'Ghi chú: $note',
                        ].join('\n')),
                        isThreeLine: note.isNotEmpty,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showEditOrderItemSheet(
                                context,
                                orderId: orderId,
                                itemId: id,
                                name: name,
                                unitPrice: price,
                                currentQty: qty,
                                currentNote: note,
                              );
                            } else if (v == 'delete') {
                              _deleteOrderItem(context, orderId: orderId, itemId: id, name: name);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Sửa món/ghi chú')),
                            PopupMenuItem(value: 'delete', child: Text('Xoá món')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _OrderActions(orderId: orderId),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final String orderId;
  const _OrderActions({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 12,
        bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Nhóm trái: quản trị bàn
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Chuyển bàn'),
                onPressed: () => _showTransferTableSheet(context, orderId: orderId),
              ),
              TextButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('Huỷ đặt / Huỷ order'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      content: const Text('Huỷ order hiện tại và trả bàn?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Có')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await repo.voidOpenOrderAndFreeTable();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),

          // Nhóm phải: tính tiền
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Xin tính tiền'),
                onPressed: () async {
                  await repo.requestBill();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã chuyển trạng thái: chờ thanh toán')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('Thanh toán & trả bàn'),
                onPressed: () async {
                  await repo.payAndFreeTable();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/success');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditOrderItemSheet(
  BuildContext context, {
  required String orderId,
  required String itemId,
  required String name,
  required double unitPrice,
  required int currentQty,
  required String currentNote,
}) async {
  final repo = InheritedApp.of(context);
  final qtyCtl = TextEditingController(text: currentQty.toString());
  final noteCtl = TextEditingController(text: currentNote);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sửa món', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtl,
                minLines: 2, maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu'),
                    onPressed: () async {
                      final qty = int.tryParse(qtyCtl.text.trim()) ?? currentQty;
                      final note = noteCtl.text.trim();
                      if (qty <= 0) {
                        await repo.removeOrderItem(orderId: orderId, itemId: itemId);
                      } else {
                        await repo.updateOrderItem(
                          orderId: orderId,
                          itemId: itemId,
                          qty: qty,
                          note: note.isEmpty ? null : note,
                        );
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật món')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Thành tiền mới: ${_vnd(unitPrice * (int.tryParse(qtyCtl.text) ?? currentQty))}',
                  style: const TextStyle(color: Colors.black54),
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _deleteOrderItem(
  BuildContext context, {
  required String orderId,
  required String itemId,
  required String name,
}) async {
  final repo = InheritedApp.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text('Xoá "$name" khỏi order?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
      ],
    ),
  );
  if (ok == true) {
    await repo.removeOrderItem(orderId: orderId, itemId: itemId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xoá món')));
  }
}

Future<void> _showTransferTableSheet(BuildContext context, {required String orderId}) async {
  final repo = InheritedApp.of(context);
  final tables = repo.tables
      .where((t) => t.state == TableState.vacant) // chỉ bàn trống
      .toList();

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) {
      if (tables.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Không có bàn trống để chuyển.'),
        );
      }
      return SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: tables.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = tables[i];
            return ListTile(
              leading: const Icon(Icons.table_bar),
              title: Text(t.name, overflow: TextOverflow.ellipsis),
              subtitle: Text('Sức chứa: ${t.capacity}'),
              onTap: () async {
                Navigator.pop(context);
                await repo.transferTable(orderId: orderId, toTableId: t.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Đã chuyển sang ${t.name}')));
              },
            );
          },
        ),
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    MaterialColor color;
    switch (status) {
      case 'billed':
        label = 'Chờ thanh toán';
        color = Colors.red;
        break;
      case 'paid':
        label = 'Đã thanh toán';
        color = Colors.green;
        break;
      case 'void':
        label = 'Đã huỷ';
        color = Colors.blueGrey;
        break;
      case 'open':
      default:
        label = 'Đang phục vụ';
        color = Colors.orange;
        break;
    }
    return Chip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      backgroundColor: color.withOpacity(.12),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color.shade700),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _vnd(double v) {
  final s = v.toStringAsFixed(0);
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final left = s.length - i - 1;
    b.write(s[i]);
    if (left > 0 && left % 3 == 0) b.write('.');
  }
  return '$b đ';
}


