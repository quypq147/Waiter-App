import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firestore_paths.dart';
import '../models/user.dart';
import '../models/table_model.dart';
import '../models/category_model.dart';
import '../models/menu_item_model.dart';
import '../models/cart_item.dart';
import '../models/revenue_point.dart';

/// AppRepository:
/// - Quản lý Auth (FirebaseAuth)
/// - Đồng bộ bàn / danh mục / món từ Firestore
/// - Quản lý giỏ + Order (tạo/sửa/xoá món, ghi chú, chuyển bàn, thanh toán, huỷ)
class AppRepository extends ChangeNotifier {
  AppRepository({String? restaurantId})
    : _rid = restaurantId ?? 'default_restaurant' {
    _init();
  }
  bool _profileLoaded = false;
  bool get isProfileLoaded => _profileLoaded;
  // ---- Firebase
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final String _rid;
  String get restaurantId => _rid;

  // ---- Auth
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ---- Data in-memory
  final List<TableModel> _tables = [];
  final List<CategoryModel> _categories = [];
  final List<MenuItemModel> _menu = [];

  List<TableModel> get tables => List.unmodifiable(_tables);
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<MenuItemModel> get menu => List.unmodifiable(_menu);

  // ---- Selection
  String? _selectedTableId;
  TableModel? get selectedTable => _selectedTableId == null
      ? null
      : _tables.firstWhere(
          (t) => t.id == _selectedTableId,
          orElse: () => TableModel(
            id: _selectedTableId!,
            name: '',
            capacity: 0,
            isAvailable: true,
            currentOrderId: null,
            state: TableState.vacant,
          ),
        );
  bool get hasSelectedTable => _selectedTableId != null;

  // ---- Active order
  String? _activeOrderId;
  String? get activeOrderId => _activeOrderId;

  // ---- Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);
  int get cartItemsCount => _cart.fold<int>(0, (acc, e) => acc + e.qty);
  double get cartTotal =>
      _cart.fold<double>(0, (acc, e) => acc + e.item.price * e.qty);

  // ---- Subscriptions
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tablesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _catsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _menuSub;

  // ===================================================================
  // Init / Dispose
  // ===================================================================
  Future<void> _init() async {
    // 1) Auth state

    _authSub = _auth.authStateChanges().listen((u) async {
      if (u == null) {
        _currentUser = null;
        _profileLoaded = true;
        _selectedTableId = null;
        _activeOrderId = null;
        _cart.clear();
        notifyListeners();
        return;
      }

      _profileLoaded = false;
      // user tạm trong lúc chờ role
      _currentUser = AppUser(
        id: u.uid,
        email: u.email ?? '',
        role: UserRole.waiter,
        password: '',
      );
      notifyListeners();

      try {
        final doc = await _db
            .collection(FP.users())
            .doc(u.uid)
            .get(); // <— ROOT
        if (doc.exists) {
          _currentUser = AppUser.fromDoc(u.uid, doc.data()!);
        } else {
          // nếu chưa có doc, giữ waiter
          _currentUser = AppUser(
            id: u.uid,
            email: u.email ?? '',
            role: UserRole.waiter,
            password: '',
          );
        }
      } catch (_) {
        _currentUser = AppUser(
          id: u.uid,
          email: u.email ?? '',
          role: UserRole.waiter,
          password: '',
        );
      }

      _profileLoaded = true;
      notifyListeners();
    });

    // 2) Tables
    _tablesSub = _db
        .collection(FP.tables(_rid))
        .orderBy('name')
        .snapshots()
        .listen((snap) {  
          _tables
            ..clear()
            ..addAll(snap.docs.map((d) => TableModel.fromMap(d.id,d.data())));
          if (_selectedTableId != null &&
              !_tables.any((t) => t.id == _selectedTableId)) {
            _selectedTableId = null;
            _activeOrderId = null;
          }
          notifyListeners();
        });

    // 3) Categories
    _catsSub = _db
        .collection(FP.categories(_rid))
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          _categories
            ..clear()
            ..addAll(
              snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())),
            );
          notifyListeners();
        });

    // 4) Menu items
    _menuSub = _db
        .collection(FP.menuItems(_rid))
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          _menu
            ..clear()
            ..addAll(
              snap.docs.map((d) {
                final m = d.data();
                return MenuItemModel(
                  id: d.id,
                  name: (m['name'] ?? '') as String,
                  price: (m['price'] ?? 0).toDouble(),
                  categoryId: (m['categoryId'] ?? '') as String,
                  description: m['description'] as String?,
                  image: m['image'] as String?,
                );
              }),
            );
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tablesSub?.cancel();
    _catsSub?.cancel();
    _menuSub?.cancel();
    super.dispose();
  }

  // ===================================================================
  // Auth
  // ===================================================================
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _profileLoaded = true;
    _selectedTableId = null;
    _activeOrderId = null;
    _cart.clear();
    notifyListeners();
  }

  // ===================================================================
  // Selection
  // ===================================================================
  // THAY thế hàm selectTable hiện tại bằng bản đa hình này:
  Future<void> selectTable(dynamic tableOrId) async {
    final String tableId = tableOrId is TableModel
        ? tableOrId.id
        : tableOrId as String;

    _selectedTableId = tableId;
    _activeOrderId = null;

    try {
      final tDoc = await _db.collection(FP.tables(_rid)).doc(tableId).get();
      if (tDoc.exists) {
        final currentOrderId = tDoc.data()?['currentOrderId'] as String?;
        if (currentOrderId != null && currentOrderId.isNotEmpty) {
          _activeOrderId = currentOrderId;
        }
      }
    } catch (_) {}

    notifyListeners();
  }

  // Setters tiện dụng cho UI trước khi mở OrderScreen
  void setSelectedTableId(String? id) {
    _selectedTableId = id;
    notifyListeners();
  }

  void setActiveOrderId(String? id) {
    _activeOrderId = id;
    notifyListeners();
  }

  // ===================================================================
  // Cart (bắt buộc có bàn trước khi thêm)
  // ===================================================================
  void addToCart(MenuItemModel item) {
    if (_selectedTableId == null) {
      throw StateError('Chưa chọn bàn');
    }
    final i = _cart.indexWhere((c) => c.item.id == item.id);
    if (i == -1) {
      _cart.add(CartItem(id: item.id, item: item, qty: 1));
    } else {
      _cart[i] = _cart[i].copyWith(qty: _cart[i].qty + 1);
    }
    notifyListeners();
  }

  void increaseQty(String cartId) {
    final i = _cart.indexWhere((c) => c.id == cartId);
    if (i != -1) {
      _cart[i] = _cart[i].copyWith(qty: _cart[i].qty + 1);
      notifyListeners();
    }
  }

  void decreaseQty(String cartId) {
    final i = _cart.indexWhere((c) => c.id == cartId);
    if (i != -1) {
      final q = _cart[i].qty - 1;
      if (q <= 0) {
        _cart.removeAt(i);
      } else {
        _cart[i] = _cart[i].copyWith(qty: q);
      }
      notifyListeners();
    }
  }

  void removeFromCart(String cartId) {
    _cart.removeWhere((c) => c.id == cartId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // ===================================================================
  // Order
  // ===================================================================
  /// Tạo order từ giỏ + chiếm bàn (state = occupied)
  Future<void> sendCartToKitchen() async {
    if (_selectedTableId == null) {
      throw StateError('Chưa chọn bàn');
    }
    if (_cart.isEmpty) return;

    final tableId = _selectedTableId!;
    final items = List<CartItem>.from(_cart);
    final subtotal = cartTotal;
    final total = subtotal;

    final batch = _db.batch();
    final orderRef = _db.collection(FP.orders(_rid)).doc();

    batch.set(orderRef, {
      'tableId': tableId,
      'waiterId': _currentUser?.id ?? '',
      'status': 'open',
      'covers': null,
      'subtotal': subtotal,
      'discount': 0,
      'serviceCharge': 0,
      'tax': 0,
      'total': total,
      'itemsCount': items.fold<int>(0, (acc, e) => acc + e.qty),
      'openedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
      'createdBy': _currentUser?.id,
    });

    final itemsCol = _db.collection(FP.orderItems(_rid, orderRef.id));
    for (final it in items) {
      final itRef = itemsCol.doc();
      batch.set(itRef, {
        'menuItemId': it.item.id,
        'name': it.item.name,
        'price': it.item.price,
        'qty': it.qty,
        'note': it.note,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final tableRef = _db.collection(FP.tables(_rid)).doc(tableId);
    batch.update(tableRef, {
      'isAvailable': false,
      'state': 'occupied',
      'currentOrderId': orderRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    _activeOrderId = orderRef.id;
    _cart.clear();
    notifyListeners();
  }

  Future<void> requestBill() async {
    final oid = _activeOrderId;
    final tid = _selectedTableId;
    if (oid == null || tid == null) return;

    final orderRef = _db.collection(FP.orders(_rid)).doc(oid);
    final tableRef = _db.collection(FP.tables(_rid)).doc(tid);

    final batch = _db.batch();
    batch.update(orderRef, {
      'status': 'billed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(tableRef, {
      'state': 'billed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> payAndFreeTable() async {
    final oid = _activeOrderId;
    final tid = _selectedTableId;
    if (oid == null || tid == null) return;

    final orderRef = _db.collection(FP.orders(_rid)).doc(oid);
    final tableRef = _db.collection(FP.tables(_rid)).doc(tid);

    final batch = _db.batch();
    batch.update(orderRef, {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': FieldValue.serverTimestamp(),
    });
    batch.update(tableRef, {
      'isAvailable': true,
      'state': 'vacant',
      'currentOrderId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    _activeOrderId = null;
    notifyListeners();
  }

  Future<void> voidOpenOrderAndFreeTable() async {
    final oid = _activeOrderId;
    final tid = _selectedTableId;
    if (oid == null || tid == null) return;

    final orderRef = _db.collection(FP.orders(_rid)).doc(oid);
    final tableRef = _db.collection(FP.tables(_rid)).doc(tid);

    final batch = _db.batch();
    batch.update(orderRef, {
      'status': 'void',
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': FieldValue.serverTimestamp(),
    });
    batch.update(tableRef, {
      'isAvailable': true,
      'state': 'vacant',
      'currentOrderId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    _activeOrderId = null;
    notifyListeners();
  }

  Future<void> updateOrderItem({
    required String orderId,
    required String itemId,
    required int qty,
    String? note,
  }) async {
    final itemRef = _db.collection(FP.orderItems(_rid, orderId)).doc(itemId);
    if (qty <= 0) {
      await itemRef.delete();
    } else {
      await itemRef.update({
        'qty': qty,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await _recalcOrderTotals(orderId);
  }

  Future<void> removeOrderItem({
    required String orderId,
    required String itemId,
  }) async {
    final itemRef = _db.collection(FP.orderItems(_rid, orderId)).doc(itemId);
    await itemRef.delete();
    await _recalcOrderTotals(orderId);
  }

  Future<void> transferTable({
    required String orderId,
    required String toTableId,
  }) async {
    final orderRef = _db.collection(FP.orders(_rid)).doc(orderId);
    final od = await orderRef.get();
    final fromTableId = (od.data()?['tableId'] ?? '') as String;
    if (fromTableId == toTableId || toTableId.isEmpty) return;

    final fromTableRef = _db.collection(FP.tables(_rid)).doc(fromTableId);
    final toTableRef = _db.collection(FP.tables(_rid)).doc(toTableId);

    await _db.runTransaction((tx) async {
      tx.update(orderRef, {
        'tableId': toTableId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(fromTableRef, {
        'isAvailable': true,
        'state': 'vacant',
        'currentOrderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(toTableRef, {
        'isAvailable': false,
        'state': 'occupied',
        'currentOrderId': orderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (_activeOrderId == orderId) {
      _selectedTableId = toTableId;
      notifyListeners();
    }
  }

  Future<void> _recalcOrderTotals(String orderId) async {
    final itemsSnap = await _db.collection(FP.orderItems(_rid, orderId)).get();
    double subtotal = 0;
    int count = 0;
    for (final d in itemsSnap.docs) {
      final m = d.data();
      final price = (m['price'] ?? 0).toDouble();
      final qty = (m['qty'] ?? 0) as int;
      subtotal += price * qty;
      count += qty;
    }
    final total = subtotal;

    await _db.collection(FP.orders(_rid)).doc(orderId).update({
      'subtotal': subtotal,
      'total': total,
      'itemsCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================================================================
  // Revenue
  // ===================================================================
  Future<List<RevenuePoint>> fetchRevenue({
    required DateTime from,
    required DateTime to,
    required RevenueGroupBy groupBy,
  }) async {
    final q = await FirebaseFirestore.instance
        .collection(FP.orders(_rid))
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('paidAt', isLessThan: Timestamp.fromDate(to))
        .orderBy('paidAt', descending: true) 
        .get();

    final Map<DateTime, _Agg> buckets = {};
    for (final d in q.docs) {
      final m = d.data();

      final double total = (m['total'] ?? 0) is num
          ? (m['total'] as num).toDouble()
          : double.tryParse('${m['total']}') ?? 0.0;

      final DateTime? paidAt =
          (m['paidAt'] as Timestamp?)?.toDate() ??
          (m['updatedAt'] as Timestamp?)?.toDate();
      if (paidAt == null) continue;

      final DateTime key = groupBy == RevenueGroupBy.day
          ? DateTime(paidAt.year, paidAt.month, paidAt.day)
          : DateTime(paidAt.year, paidAt.month, 1);

      final agg = buckets.putIfAbsent(key, () => _Agg());
      agg.sum += total;
      agg.count += 1;
    }

    final keys = buckets.keys.toList()..sort();
    return keys
        .map((k) => RevenuePoint(
              bucket: k,
              total: buckets[k]!.sum,
              orders: buckets[k]!.count,
            ))
        .toList();
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    // _auth.authStateChanges() đã listen và cập nhật _currentUser
  }

  Future<void> register(
    String email,
    String password, {
    String? displayName,
    UserRole role = UserRole.waiter,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // tạo document user để lưu role
    await _db.collection(FP.users()).doc(cred.user!.uid).set({
      'email': email,
      'displayName': displayName,
      'role': role.name, // 'admin' | 'waiter' | 'chef'
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Cập nhật displayName trên Auth (tuỳ chọn)
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName);
    }
  }

  Future<void> refreshUserRole() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final doc = await _db.collection(FP.users()).doc(u.uid).get();
    if (doc.exists) {
      _currentUser = AppUser.fromDoc(u.uid, doc.data()!);
      notifyListeners();
    }
  }

  Future<void> seatTable(TableModel table, {int? covers}) async {
    final tableRef = _db.collection(FP.tables(_rid)).doc(table.id);
    await tableRef.update({
      'isAvailable': false,
      'state': 'occupied',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _selectedTableId = table.id;
    // chưa có order => _activeOrderId vẫn null
    notifyListeners();
  }

  // ==== MENU CRUD ====
  Future<void> createMenuItem({
    required String name,
    required double price,
    required String categoryId,
    String? description,
    String? image,
  }) async {
    final col = _db.collection(FP.menuItems(_rid));
    await col.add({
      'name': name,
      'price': price,
      'categoryId': categoryId,
      'description': description,
      'image': image,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenuItem(
    String id, {
    String? name,
    double? price,
    String? categoryId,
    String? description,
    String? image,
  }) async {
    final doc = _db.collection(FP.menuItems(_rid)).doc(id);
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (categoryId != null) 'categoryId': categoryId,
      if (description != null) 'description': description,
      if (image != null) 'image': image,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await doc.update(data);
  }

  Future<void> deleteMenuItem(String id) async {
    await _db.collection(FP.menuItems(_rid)).doc(id).delete();
  }

  // ==== STAFF ====
  Future<void> setUserRole(String uid, UserRole role) async {
    await _db.collection(FP.users()).doc(uid).update({
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> addOrUpdateItem({
  required String restaurantId, // không dùng – đã có _rid
  required String orderId,
  required String menuItemId,
  required String name,
  required num price,
  required int deltaQty, // +1 hoặc -1
}) async {
  final orderRef = _db.collection(FP.orders(_rid)).doc(orderId);
  final itemRef  = _db.collection(FP.orderItems(_rid, orderId)).doc(menuItemId);

  await _db.runTransaction((tx) async {
    final itemSnap = await tx.get(itemRef);
    final double unitPrice = price.toDouble();

    int currentQty = 0;
    if (itemSnap.exists) {
      currentQty = (itemSnap.data()?['qty'] ?? 0) as int;
    }

    final int newQty = currentQty + deltaQty;

    double appliedDeltaSubtotal = 0;
    int appliedDeltaCount = 0;

    if (newQty <= 0) {
      if (itemSnap.exists) {
        // xóa item ⇒ delta = -currentQty
        appliedDeltaSubtotal = -currentQty * unitPrice;
        appliedDeltaCount    = -currentQty;
        tx.delete(itemRef);
      } else {
        // không có item mà lại delta -1 ⇒ bỏ qua
        appliedDeltaSubtotal = 0;
        appliedDeltaCount    = 0;
      }
    } else {
      // tạo mới hoặc cập nhật: delta = newQty - currentQty
      final int appliedDelta = newQty - currentQty;
      appliedDeltaSubtotal = appliedDelta * unitPrice;
      appliedDeltaCount    = appliedDelta;

      if (!itemSnap.exists) {
        tx.set(itemRef, {
          'menuItemId': menuItemId,
          'name': name,
          'price': unitPrice,
          'qty': newQty,
          'note': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(itemRef, {
          'qty': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Cộng dồn về order – tránh phải đọc toàn bộ orderItems
    if (appliedDeltaCount != 0) {
      tx.update(orderRef, {
        'subtotal': FieldValue.increment(appliedDeltaSubtotal),
        'total':    FieldValue.increment(appliedDeltaSubtotal),
        'itemsCount': FieldValue.increment(appliedDeltaCount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  });
}

}

class _Agg {
  double sum = 0;
  int count = 0;
}

/// Inherited wrapper
class InheritedApp extends InheritedNotifier<AppRepository> {
  final AppRepository repo;
  const InheritedApp({super.key, required this.repo, required super.child})
    : super(notifier: repo);

  static AppRepository of(BuildContext context) {
    final i = context.dependOnInheritedWidgetOfExactType<InheritedApp>();
    assert(i != null, 'Không tìm thấy InheritedApp trong context');
    return i!.repo;
  }
}
