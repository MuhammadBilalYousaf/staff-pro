import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/models/menu_models.dart';
import 'package:staffpro/state/app_state.dart';
import 'package:uuid/uuid.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  PublicMenu? _menu;
  bool _saving = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    final existing = app.publicMenu;
    final businessId = app.currentUser?.businessId;
    if (existing != null) {
      _menu = PublicMenu.fromJson(existing.toJson());
    } else if (businessId != null) {
      _menu = PublicMenu(businessId: businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final menu = _menu;
    final canEdit = app.canEditMenu;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          if (canEdit && menu != null)
            TextButton(
              onPressed: _saving ? null : () => _save(app),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
        ],
      ),
      floatingActionButton: canEdit && menu != null
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _addCategory,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: menu == null
          ? const EmptyView(title: 'No business selected')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                const Text(
                  'This menu is what customers will see. Variant price replaces the base price. Add-on price is added on top.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                if (menu.categories.isEmpty) const EmptyView(title: 'No categories yet'),
                for (final category in menu.categories) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            if (!category.active)
                              const Text('Hidden', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            if (canEdit)
                              IconButton(onPressed: () => _editCategory(category), icon: const Icon(Icons.edit_outlined)),
                          ],
                        ),
                        for (final product in category.products)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _ProductThumb(url: product.imageUrl),
                            title: Text(product.name),
                            subtitle: Text(_productSubtitle(product)),
                            trailing: canEdit
                                ? IconButton(onPressed: () => _editProduct(category, product), icon: const Icon(Icons.chevron_right))
                                : null,
                            onTap: canEdit ? () => _editProduct(category, product) : null,
                          ),
                        if (canEdit)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _editProduct(category, null),
                              icon: const Icon(Icons.add),
                              label: const Text('Add product'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  String _productSubtitle(MenuProduct product) {
    final price = product.variants.isEmpty ? product.price.toStringAsFixed(0) : '${product.variants.length} variants';
    final state = product.available ? '' : ' · unavailable';
    return '$price$state';
  }

  Future<void> _addCategory() async {
    final category = await _categoryDialog(null);
    if (category == null || _menu == null) return;
    setState(() => _menu!.categories.add(category));
  }

  Future<void> _editCategory(MenuCategory category) async {
    final edited = await _categoryDialog(category);
    if (edited == null) return;
    setState(() {
      category
        ..name = edited.name
        ..active = edited.active
        ..sort = edited.sort;
    });
  }

  Future<MenuCategory?> _categoryDialog(MenuCategory? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var active = existing?.active ?? true;
    final result = await showDialog<MenuCategory>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (v) => setSt(() => active = v),
                title: const Text('Visible to customers'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  MenuCategory(
                    id: existing?.id ?? _uuid.v4(),
                    name: name.text.trim(),
                    sort: existing?.sort ?? (_menu?.categories.length ?? 0),
                    active: active,
                    products: existing?.products ?? [],
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _editProduct(MenuCategory category, MenuProduct? existing) async {
    final product = await showDialog<MenuProduct>(
      context: context,
      builder: (ctx) => _ProductDialog(existing: existing),
    );
    if (product == null) return;
    setState(() {
      final index = category.products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        category.products[index] = product;
      } else {
        category.products.add(product);
      }
    });
  }

  Future<void> _save(StaffProController app) async {
    final menu = _menu;
    if (menu == null) return;
    setState(() => _saving = true);
    try {
      await app.savePublicMenu(menu);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menu saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Widget _menuImage(String url, Widget fallback) {
  if (url.startsWith('data:image')) {
    final comma = url.indexOf(',');
    if (comma < 0) return fallback;
    try {
      return Image.memory(base64Decode(url.substring(comma + 1)), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    } catch (_) {
      return fallback;
    }
  }
  if (url.startsWith('http')) {
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
  return fallback;
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: _menuImage(url, const ColoredBox(color: Color(0xFFE8E4DE), child: Icon(Icons.fastfood_outlined))),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.existing});
  final MenuProduct? existing;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  String _image = '';
  late final TextEditingController _price;
  late final TextEditingController _variants;
  late final TextEditingController _addons;
  late bool _available;
  bool _uploading = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final product = widget.existing;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    final savedImage = product?.imageUrl ?? '';
    _image = savedImage;
    _imageUrl = TextEditingController(text: savedImage.startsWith('http') ? savedImage : '');
    _price = TextEditingController(text: product == null ? '' : product.price.toStringAsFixed(0));
    _variants = TextEditingController(text: _formatChoices(product?.variants ?? []));
    _addons = TextEditingController(text: _formatChoices(product?.addons ?? []));
    _available = product?.available ?? true;
  }

  String _formatChoices(List<MenuChoice> choices) {
    return choices.map((c) => '${c.name}=${c.price.toStringAsFixed(0)}').join('\n');
  }

  List<MenuChoice> _parseChoices(String raw, List<MenuChoice> previous) {
    final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final result = <MenuChoice>[];
    for (final line in lines) {
      final parts = line.split('=');
      final name = parts.first.trim();
      if (name.isEmpty) continue;
      final price = parts.length > 1 ? double.tryParse(parts[1].trim()) ?? 0 : 0.0;
      String? reusedId;
      for (final choice in previous) {
        if (choice.name.toLowerCase() == name.toLowerCase()) {
          reusedId = choice.id;
          break;
        }
      }
      result.add(MenuChoice(id: reusedId ?? _uuid.v4(), name: name, price: price));
    }
    return result;
  }

  Future<void> _uploadImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 45, maxWidth: 640);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 200000) {
        if (mounted) showToast(context, 'That photo is too large. Paste an image URL instead.', error: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _imageUrl.clear();
        _image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (error) {
      if (mounted) showToast(context, 'Could not read that photo. Paste an image URL instead.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add product' : 'Edit product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
            TextField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                helperText: 'Paste a link, or upload a photo. Uploaded photos are saved with the menu.',
              ),
              onChanged: (value) => setState(() => _image = value.trim()),
            ),
            const SizedBox(height: 8),
            if (_image.startsWith('http') || _image.startsWith('data:image'))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _menuImage(_image, const SizedBox.shrink()),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _uploading ? null : _uploadImage,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_outlined),
                label: Text(_uploading ? 'Uploading…' : 'Upload image'),
              ),
            ),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Base price'),
            ),
            TextField(
              controller: _variants,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Variants',
                helperText: 'One per line: Single=250',
              ),
            ),
            TextField(
              controller: _addons,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Add-ons',
                helperText: 'One per line: Extra cheese=50',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              title: const Text('Available'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            final previous = widget.existing;
            Navigator.pop(
              context,
              MenuProduct(
                id: previous?.id ?? _uuid.v4(),
                name: _name.text.trim(),
                description: _description.text.trim(),
                imageUrl: _imageUrl.text.trim().startsWith('http') ? _imageUrl.text.trim() : _image,
                price: double.tryParse(_price.text.trim()) ?? 0,
                available: _available,
                variants: _parseChoices(_variants.text, previous?.variants ?? []),
                addons: _parseChoices(_addons.text, previous?.addons ?? []),
              ),
            );
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
