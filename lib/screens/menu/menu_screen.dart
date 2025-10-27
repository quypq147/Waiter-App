import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../models/menu_item_model.dart';
import '../../widgets/app_drawer.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _categoryId;
  String _kw = '';

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    final table = repo.selectedTable;
    final categories = repo.categories;

    final items = repo.menu.where((m) {
      final okCat = _categoryId == null || m.categoryId == _categoryId;
      final okKw = _kw.isEmpty || m.name.toLowerCase().contains(_kw.toLowerCase());
      return okCat && okKw;
    }).toList();

    final hasTable = table != null;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          hasTable ? 'Menu • ${table.name}' : 'Menu',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Giỏ hàng',
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pushReplacementNamed(context, '/cart'),
          ),
        ],
      ),

      body: Column(
        children: [
          if (!hasTable)
            MaterialBanner(
              content: const Text('Bạn cần chọn bàn trước khi thêm món.'),
              leading: const Icon(Icons.info_outline),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/select_table'),
                  child: const Text('Chọn bàn'),
                ),
              ],
            ),

          // Filter ngang – tránh overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm món…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => setState(() => _kw = s),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _categoryId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tất cả danh mục')),
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Không có món phù hợp'))
                : LayoutBuilder(
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
                          childAspectRatio: 1.6,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _MenuCard(
                          item: items[i],
                          enabled: hasTable, // <- bắt buộc có bàn
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 72),
        ],
      ),

      floatingActionButton: AnimatedBuilder(
        animation: repo,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: () => Navigator.pushReplacementNamed(context, '/cart'),
          icon: const Icon(Icons.shopping_cart_checkout),
          label: Text('Giỏ (${repo.cartItemsCount})'),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItemModel item;
  final bool enabled;
  const _MenuCard({required this.item, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_vnd(item.price), style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
                onPressed: !enabled
                    ? null
                    : () {
                        repo.addToCart(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã thêm ${item.name}')),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
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



