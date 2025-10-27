import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demodidong/core/firestore_paths.dart';
import 'package:demodidong/data/app_repository.dart';
import 'package:demodidong/models/category_model.dart';
import 'package:demodidong/models/menu_item_model.dart';
import 'package:flutter/material.dart';

/// ================= TAB 2: MÓN ĂN (CRUD) =================

class AdminMenuTab extends StatefulWidget {
  const AdminMenuTab({super.key});

  @override
  State<AdminMenuTab> createState() => _MenuCrudTabState();
}

class _MenuCrudTabState extends State<AdminMenuTab> {
  
  String _keyword = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    return AnimatedBuilder(
      animation: repo,
      builder: (_, __) {
        final categories = repo.categories;
        final allItems = repo.menu;
        final items = allItems.where((m) {
          final okCat = _categoryId == null || m.categoryId == _categoryId;
          final okKw = m.name.toLowerCase().contains(_keyword.toLowerCase());
          return okCat && okKw;
        }).toList();

        return Column(
          children: [
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
                      onChanged: (s) => setState(() => _keyword = s),
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
                            childAspectRatio: 1.5,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _MenuCrudCard(
                            item: items[i],
                            category: categories.firstWhere(
                              (c) => c.id == items[i].categoryId,
                              orElse: () => CategoryModel(id: '', name: 'Khác'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuCrudCard extends StatelessWidget {
  final MenuItemModel item;
  final CategoryModel category;
  const _MenuCrudCard({required this.item, required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Danh mục: ${category.name}', overflow: TextOverflow.ellipsis),
            Text('Giá: ${item.price.toStringAsFixed(0)} đ'),
            if ((item.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            const Spacer(),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showMenuForm(context, existing: item),
                  icon: const Icon(Icons.edit),
                  label: const Text('Sửa'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteMenuItem(context, item),
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
}

Future<void> _deleteMenuItem(BuildContext context, MenuItemModel item) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Xoá món?'),
      content: Text('Bạn có chắc muốn xoá "${item.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
      ],
    ),
  );
  if (ok != true) return;

  const rid = 'default_restaurant';
  await FirebaseFirestore.instance.collection(FP.menuItems(rid)).doc(item.id).delete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xoá ${item.name}')));
}

Future<void> _showMenuForm(BuildContext context, {MenuItemModel? existing}) async {
  final repo = InheritedApp.of(context);
  final categories = repo.categories;

  String? categoryId = existing?.categoryId ?? (categories.isNotEmpty ? categories.first.id : null);
  final nameCtl = TextEditingController(text: existing?.name ?? '');
  final priceCtl = TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '');
  final descCtl = TextEditingController(text: existing?.description ?? '');

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
              Text(existing == null ? 'Thêm món' : 'Sửa món',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                items: categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => categoryId = v,
                decoration: const InputDecoration(
                  labelText: 'Danh mục', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Tên món', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá (VND)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)', border: OutlineInputBorder(), isDense: true),
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
                      final price = double.tryParse(priceCtl.text.trim());
                      if (categoryId == null || name.isEmpty || price == null || price < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng điền đầy đủ & hợp lệ')),
                        );
                        return;
                      }

                      const rid = 'default_restaurant';
                      final col = FirebaseFirestore.instance.collection(FP.menuItems(rid));

                      if (existing == null) {
                        await col.add({
                          'name': name,
                          'price': price,
                          'categoryId': categoryId,
                          'description': descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã thêm món $name')),
                        );
                      } else {
                        await col.doc(existing.id).update({
                          'name': name,
                          'price': price,
                          'categoryId': categoryId,
                          'description': descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã cập nhật ${existing.name}')),
                        );
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