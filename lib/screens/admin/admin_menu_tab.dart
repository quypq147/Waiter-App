import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../models/menu_item_model.dart';
import '../../models/category_model.dart';

class AdminMenuTab extends StatelessWidget {
  const AdminMenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth > 720;
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Quản lý món', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm món'),
                    onPressed: () => _openItemSheet(context, repo),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _MenuList(repo: repo, isWide: isWide),
              ),
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: body,
          );
        },
      ),
    );
  }

  Future<void> _openItemSheet(BuildContext context, AppRepository repo, {MenuItemModel? item}) async {
    final nameCtl = TextEditingController(text: item?.name ?? '');
    final priceCtl = TextEditingController(text: item?.price.toString() ?? '');
    final descCtl = TextEditingController(text: item?.description ?? '');
    final imageCtl = TextEditingController(text: item?.image ?? '');
    String? categoryId = item?.categoryId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item == null ? 'Thêm món' : 'Sửa món', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Tên món', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    items: repo.categories
                        .map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                    onChanged: (v) => categoryId = v,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Giá', border: OutlineInputBorder(), prefixText: '₫ '),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageCtl,
                    decoration: const InputDecoration(labelText: 'Ảnh (URL, tuỳ chọn)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Huỷ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtl.text.trim();
                            final price = double.tryParse(priceCtl.text.replaceAll(',', '.')) ?? 0;
                            if (name.isEmpty || categoryId == null || price <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Tên, danh mục, giá không hợp lệ')));
                              return;
                            }
                            if (item == null) {
                              await repo.createMenuItem(
                                name: name,
                                price: price,
                                categoryId: categoryId!,
                                description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                                image: imageCtl.text.trim().isEmpty ? null : imageCtl.text.trim(),
                              );
                            } else {
                              await repo.updateMenuItem(
                                item.id,
                                name: name,
                                price: price,
                                categoryId: categoryId!,
                                description: descCtl.text.trim(),
                                image: imageCtl.text.trim(),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(item == null ? 'Lưu' : 'Cập nhật'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.repo, required this.isWide});
  final AppRepository repo;
  final bool isWide;

  String _catName(String id) {
    return repo.categories.firstWhere(
      (c) => c.id == id,
      orElse: () => CategoryModel(id: id, name: '—'),
    ).name;
  }

  @override
  Widget build(BuildContext context) {
    final items = repo.menu;
    if (items.isEmpty) {
      return const Center(child: Text('Chưa có món nào'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = items[i];
        return ListTile(
          title: Text(m.name),
          subtitle: Text('${_catName(m.categoryId)} • ₫${m.price.toStringAsFixed(0)}'),
          trailing: Wrap(spacing: 8, children: [
            IconButton(
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit),
              onPressed: () => AdminMenuTab()._openItemSheet(context, repo, item: m),
            ),
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xoá món?'),
                    content: Text('Bạn chắc chắn muốn xoá "${m.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
                    ],
                  ),
                );
                if (ok == true) {
                  await repo.deleteMenuItem(m.id);
                }
              },
            ),
          ]),
        );
      },
    );
  }
}
