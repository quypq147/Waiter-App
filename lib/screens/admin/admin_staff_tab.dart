/* ========================= TAB 4: NHÂN VIÊN (NEW) ========================= */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demodidong/core/firestore_paths.dart';
import 'package:flutter/material.dart';

class AdminStaffTab extends StatefulWidget {
  const AdminStaffTab({super.key});

  @override
  State<AdminStaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<AdminStaffTab> {
  String _kw = '';
  String? _role; // null: tất cả, 'admin' hoặc 'waiter'

  @override
  Widget build(BuildContext context) {
    const rid = 'default_restaurant'; // TODO: thay bằng repo.restaurantId nếu có
    final col = FirebaseFirestore.instance.collection(FP.users()).orderBy('displayName');

    return Scaffold(
      body: Column(
        children: [
          // thanh lọc & tìm
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm tên/email…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => setState(() => _kw = s.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả vai trò')),
                      DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'chef', child: Text('Chef')),
                    ],
                    onChanged: (v) => setState(() => _role = v),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: col.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = (snap.data?.docs ?? []).where((d) {
                  final data = d.data();
                  final name = (data['displayName'] ?? '') as String;
                  final email = (data['email'] ?? '') as String;
                  final role = (data['role'] ?? '') as String;
                  final okRole = _role == null || role == _role;
                  final okKw = _kw.isEmpty ||
                      name.toLowerCase().contains(_kw.toLowerCase()) ||
                      email.toLowerCase().contains(_kw.toLowerCase());
                  return okRole && okKw;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có nhân viên'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final u = docs[i].data();
                    return _StaffTile(id: id, data: u);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm nhân viên'),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _StaffTile({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] ?? '') as String;
    final email = (data['email'] ?? '') as String;
    final role = (data['role'] ?? 'waiter') as String;
    final active = (data['isActive'] ?? true) as bool;

    MaterialColor color;
    String roleLabel;
    switch (role) {
      case 'admin': roleLabel = 'Admin'; color = Colors.deepPurple; break;
      case 'waiter':
      default: roleLabel = 'Waiter'; color = Colors.blue; break;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name.isEmpty ? '(Chưa đặt tên)' : name, overflow: TextOverflow.ellipsis),
        subtitle: Text(email, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Chip(
              label: Text(roleLabel),
              backgroundColor: color.withOpacity(.12),
              side: BorderSide(color: color),
              labelStyle: TextStyle(color: color.shade700),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Chip(
              label: Text(active ? 'Đang hoạt động' : 'Tạm khoá'),
              backgroundColor: (active ? Colors.green : Colors.grey).withOpacity(.12),
              side: BorderSide(color: active ? Colors.green : Colors.grey),
              labelStyle: TextStyle(color: (active ? Colors.green : Colors.grey).shade700),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  _showStaffForm(context, id: id, existing: data);
                } else if (v == 'delete') {
                  _deleteStaff(context, id: id, name: name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xoá')),
              ],
            ),
          ],
        ),
        onTap: () => _showStaffForm(context, id: id, existing: data),
      ),
    );
  }
}

Future<void> _deleteStaff(BuildContext context, {required String id, required String name}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Xoá nhân viên?'),
      content: Text('Bạn có chắc muốn xoá "$name"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
      ],
    ),
  );
  if (ok != true) return;
  const rid = 'default_restaurant';
  await FirebaseFirestore.instance.collection(FP.users()).doc(id).delete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xoá $name')));
}

Future<void> _showStaffForm(BuildContext context, {String? id, Map<String, dynamic>? existing}) async {
  final nameCtl = TextEditingController(text: (existing?['displayName'] ?? '') as String);
  final emailCtl = TextEditingController(text: (existing?['email'] ?? '') as String);
  String role = (existing?['role'] ?? 'waiter') as String;
  bool isActive = (existing?['isActive'] ?? true) as bool;

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
              Text(id == null ? 'Thêm nhân viên' : 'Sửa nhân viên',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => role = v ?? 'waiter',
                decoration: const InputDecoration(
                  labelText: 'Vai trò', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: isActive,
                onChanged: (v) => isActive = v,
                title: const Text('Đang hoạt động'),
                contentPadding: EdgeInsets.zero,
                dense: true,
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
                      final email = emailCtl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email không hợp lệ')),
                        );
                        return;
                      }

                      const rid = 'default_restaurant';
                      final ref = FirebaseFirestore.instance.collection(FP.users());

                      final payload = {
                        'displayName': name.isEmpty ? email.split('@').first : name,
                        'email': email,
                        'role': role, // 'admin' | 'waiter'
                        'isActive': isActive,
                        'updatedAt': FieldValue.serverTimestamp(),
                        if (id == null) 'createdAt': FieldValue.serverTimestamp(),
                      };

                      if (id == null) {
                        await ref.add(payload);
                      } else {
                        await ref.doc(id).update(payload);
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(id == null ? 'Đã thêm nhân viên' : 'Đã cập nhật')),
                      );
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