import 'package:demodidong/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firestore_paths.dart';
import '../../data/app_repository.dart';
import 'order_screen.dart';

class OrdersListScreen extends StatelessWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const activeStatuses = ['open'];
    final repo = InheritedApp.of(context);
    final rid = repo.restaurantId;

    // Cache tên bàn để tra nhanh O(1)
    final tableNameById = {
      for (final t in repo.tables) t.id: (t.name.isEmpty ? t.id : t.name),
    };

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Danh sách đơn')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(FP.orders(rid)) // ví dụ: restaurants/$rid/orders
            .where('status', whereIn: activeStatuses) // CHỈ lấy đơn active
            .orderBy('openedAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có đơn nào'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();

              final id = d.id;
              final tableId = (m['tableId'] ?? '') as String;
              final itemsCount = (m['itemsCount'] ?? 0) is num
                  ? (m['itemsCount'] as num).toInt()
                  : int.tryParse('${m['itemsCount']}') ?? 0;
              final total = (m['total'] ?? 0) is num
                  ? (m['total'] as num).toDouble()
                  : double.tryParse('${m['total']}') ?? 0.0;
              final status = (m['status'] ?? 'open') as String;

              final openedAtTs = m['openedAt'] as Timestamp?;
              final openedAt = openedAtTs?.toDate();

              final tableName = tableId.isNotEmpty
                  ? (tableNameById[tableId] ?? tableId)
                  : '';

              final subtitle = <String>[
                if (tableId.isNotEmpty) tableName,
                if (itemsCount > 0) 'Món: $itemsCount',
                if (total > 0) 'Tổng: ${total.toStringAsFixed(0)}',
                if (openedAt != null) 'Mở: ${_fmt(openedAt)}',
              ].join(' • ');

              return ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(
                  '#$id',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(subtitle),
                trailing: _StatusChip(status: status),
                onTap: () {
                  repo.setSelectedTableId(tableId.isEmpty ? null : tableId);
                  repo.setActiveOrderId(id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrderScreen()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

String _fmt(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  final hh = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$m';
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = (status.isEmpty ? 'open' : status).toLowerCase();
    Color color;
    switch (s) {
      case 'preparing':
        color = Colors.orange;
        break;
      case 'serving':
        color = Colors.green;
        break;
      case 'billed':
        color = Colors.purple;
        break;
      case 'paid':
        color = Colors.grey;
        break;
      case 'void':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }
    return Chip(label: Text(s), backgroundColor: color.withOpacity(0.15));
  }
}
