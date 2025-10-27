import 'package:demodidong/screens/admin/admin_menu_tab.dart';
import 'package:demodidong/screens/admin/admin_revenue_tab.dart';
import 'package:demodidong/screens/admin/admin_staff_tab.dart';
import 'package:demodidong/screens/admin/admin_tables_tab.dart';
import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../widgets/app_drawer.dart';



class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] is int) {
      final t = (args['tab'] as int).clamp(0, 3);
      if (_tab.index != t) _tab.index = t;
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);

    return Scaffold(
      drawer: AppDrawer(
        currentIndex: _tab.index,
        onSelectIndex: (i) {
          _tab.index = i;
          setState(() {});
        },
        onLogout: () async => repo.logout(),
      ),
      appBar: AppBar(
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.table_bar), text: 'Bàn'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Món ăn'),
            Tab(icon: Icon(Icons.auto_graph), text: 'Doanh thu'),
            Tab(icon: Icon(Icons.badge), text: 'Nhân viên'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(), // tránh swipe gây lệch state
        children: const [
          AdminTablesTab(),
          AdminMenuTab(),
          AdminRevenueTab(),
          AdminStaffTab(),
        ],
      ),
    );
  }
}





