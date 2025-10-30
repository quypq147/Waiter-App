// main.dart
import 'package:demodidong/screens/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'data/app_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/tables/table_screen.dart';
import 'screens/menu/menu_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/success/order_success_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/order/orders_list_screen.dart';
import 'screens/order/order_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final repo = AppRepository(restaurantId: 'default_restaurant');
  

  runApp( 
    ProviderScope(
      child: InheritedApp(repo: repo, child: const WaiterApp()),
    ),
  );
}

class WaiterApp extends StatelessWidget {
  const WaiterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waiter App',
      theme: buildTheme(),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/select_table': (_) => const TableScreen(),
        '/menu': (_) => const MenuScreen(),
        '/cart': (_) => const CartScreen(),
        '/order': (_) => const OrdersListScreen(),
        '/order_detail': (_) => const OrderScreen(),
        '/success': (_) => const OrderSuccessScreen(),
        '/admin': (_) => const AdminDashboard(),
      },
    );
  }
}

