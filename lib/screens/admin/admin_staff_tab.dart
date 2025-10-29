import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/app_repository.dart';
import '../../models/user.dart';
import '../../core/firestore_paths.dart';

class AdminStaffTab extends StatelessWidget {
  const AdminStaffTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    final me = repo.currentUser;

    if (me?.role != UserRole.admin) {
      return const Center(child: Text('Bạn không có quyền truy cập tab này'));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(FP.users())
              .orderBy('email')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(child: Text('Chưa có nhân viên'));
            }

            final docs = snap.data!.docs;

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i];
                final uid = d.id;
                final data = d.data();
                final email = (data['email'] ?? '') as String;
                final displayName = (data['displayName'] ?? '') as String;
                final roleStr = (data['role'] ?? 'waiter').toString().toLowerCase();
                final role = switch (roleStr) {
                  'admin' => UserRole.admin,
                  'chef' => UserRole.chef,
                  _ => UserRole.waiter,
                };

                return ListTile(
                  leading: CircleAvatar(child: Text((displayName.isNotEmpty ? displayName[0] : (email.isNotEmpty ? email[0] : '?')).toUpperCase())),
                  title: Text(displayName.isNotEmpty ? displayName : email),
                  subtitle: Text(email),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      DropdownButton<UserRole>(
                        value: role,
                        onChanged: (r) async {
                          if (r == null) return;
                          await repo.setUserRole(uid, r);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vai trò')));
                        },
                        items: const [
                          DropdownMenuItem(value: UserRole.waiter, child: Text('waiter')),
                          DropdownMenuItem(value: UserRole.chef, child: Text('chef')),
                          DropdownMenuItem(value: UserRole.admin, child: Text('admin')),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Gửi reset password',
                        icon: const Icon(Icons.lock_reset),
                        onPressed: () async {
                          final e = email.trim();
                          if (e.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tài khoản chưa có email')));
                            return;
                          }
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
                          // Thông báo
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi email đặt lại mật khẩu tới $e')));
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
