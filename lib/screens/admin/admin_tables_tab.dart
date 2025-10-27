import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demodidong/core/firestore_paths.dart';
import 'package:demodidong/data/app_repository.dart';
import 'package:demodidong/models/table_model.dart';
import 'package:flutter/material.dart';


/// ================= TAB 1: BÀN (CRUD) =================

class AdminTablesTab extends StatelessWidget {
  const AdminTablesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    return AnimatedBuilder(
      animation: repo, // chỉ tab này rebuild theo repo
      builder: (_, __) {
        final tables = repo.tables;
        if (tables.isEmpty) {
          return const Center(child: Text('Chưa có bàn nào'));
        }
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            int cross = 2;
            if (w >= 1200) {
              cross = 4;
            } else if (w >= 900) cross = 3;
            else if (w >= 600) cross = 2;
            else cross = 1;

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: tables.length,
              itemBuilder: (_, i) => _TableCrudCard(t: tables[i]),
            );
          },
        );
      },
    );
  }
}

class _TableCrudCard extends StatelessWidget {
  final TableModel t;
  const _TableCrudCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final color = switch (t.state) {
      TableState.vacant => Colors.green,
      TableState.occupied => Colors.orange,
      TableState.billed => Colors.red,
      TableState.cleaning => Colors.blueGrey,
      TableState.reserved => Colors.purple,
    };

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Chip(
                  label: Text(_labelState(t.state), overflow: TextOverflow.ellipsis),
                  backgroundColor: color.withOpacity(.12),
                  side: BorderSide(color: color),
                  labelStyle: TextStyle(color: color.shade700),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      _showTableForm(context, existing: t);
                    } else if (v == 'delete') {
                      _deleteTable(context, t);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xoá')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Sức chứa: ${t.capacity}'),
            if ((t.currentOrderId ?? '').isNotEmpty)
              Text('Order: #${t.currentOrderId!.substring(0, 6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showTableForm(context, existing: t),
                  icon: const Icon(Icons.edit),
                  label: const Text('Sửa'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteTable(context, t),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xoá'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _labelState(TableState s) => switch (s) {
        TableState.vacant => 'Trống',
        TableState.occupied => 'Đang phục vụ',
        TableState.billed => 'Chờ thanh toán',
        TableState.cleaning => 'Đang dọn',
        TableState.reserved => 'Đã đặt',
      };
}

Future<void> _deleteTable(BuildContext context, TableModel t) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Xoá bàn?'),
      content: Text(
        t.state == TableState.vacant
            ? 'Bạn có chắc muốn xoá ${t.name}?'
            : 'Bàn đang không trống, xoá có thể làm mất liên kết order.\nBạn có chắc muốn xoá ${t.name}?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
      ],
    ),
  );
  if (ok != true) return;

  const rid = 'default_restaurant';
  await FirebaseFirestore.instance.collection(FP.tables(rid)).doc(t.id).delete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xoá ${t.name}')));
}

Future<void> _showTableForm(BuildContext context, {TableModel? existing}) async {
  final nameCtl = TextEditingController(text: existing?.name ?? '');
  final capCtl = TextEditingController(text: existing?.capacity.toString() ?? '2');

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
              Text(existing == null ? 'Thêm bàn' : 'Sửa bàn',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Tên bàn', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sức chứa', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu'),
                    onPressed: () async {
                      final name = nameCtl.text.trim();
                      final capacity = int.tryParse(capCtl.text.trim());
                      if (name.isEmpty || capacity == null || capacity <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập tên & sức chứa hợp lệ')),
                        );
                        return;
                      }

                      const rid = 'default_restaurant';
                      final col = FirebaseFirestore.instance.collection(FP.tables(rid));

                      if (existing == null) {
                        await col.add({
                          'name': name,
                          'capacity': capacity,
                          'isAvailable': true,
                          'currentOrderId': null,
                          'state': 'vacant',
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Đã thêm bàn $name')));
                      } else {
                        await col.doc(existing.id).update({
                          'name': name,
                          'capacity': capacity,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Đã cập nhật ${existing.name}')));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}