import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../auth/login_screen.dart';
import '../tables/table_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../models/user.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);

    // Rebuild khi repo (auth state/role) thay đổi
    return AnimatedBuilder(
      animation: repo,
      builder: (_, __) {
        // Chưa đăng nhập → Login
        if (!repo.isLoggedIn) {
          return const LoginScreen();
        }

        // Đang đăng nhập: cần có currentUser để biết role
        final u = repo.currentUser;
        if (u == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Phân nhánh theo role
        switch (u.role) {
          case UserRole.admin:
            return const AdminDashboard();
          case UserRole.waiter:
          case UserRole.chef:
          default:
            return const TableScreen();
        }
      },
    );
  }
}


