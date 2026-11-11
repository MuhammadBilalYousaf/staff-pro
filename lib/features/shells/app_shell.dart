import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/brand_logo.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/state/app_state.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell, required this.items});

  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final List<int> _history = [widget.navigationShell.currentIndex];
  bool _restoringTab = false;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (_restoringTab) {
      if (index == _history.last) _restoringTab = false;
      return;
    }
    if (_history.last != index) _history.add(index);
  }

  void _selectTab(int index) {
    if (index == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    setState(() => _history.add(index));
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final items = widget.items;
    final app = context.watch<StaffProController>();
    final user = app.currentUser;
    final tab = items[navigationShell.currentIndex];
    final biz = user?.businessId == null ? '' : app.businessName(user?.businessId);
    final subtitle = user == null
        ? null
        : (biz.isEmpty || biz == '—' ? roleLabel(user.role) : '${roleLabel(user.role)} · $biz');

    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _history.length <= 1) return;
        _restoringTab = true;
        setState(() => _history.removeLast());
        navigationShell.goBranch(_history.last);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: ScreenHeader(title: tab.label, subtitle: subtitle),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: navigationShell,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _FloatingGlassNav(
          items: items,
          currentIndex: navigationShell.currentIndex,
          unread: app.unreadCount,
          onSelect: _selectTab,
        ),
      ),
    );
  }
}

class _FloatingGlassNav extends StatelessWidget {
  const _FloatingGlassNav({
    required this.items,
    required this.currentIndex,
    required this.unread,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final int unread;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.glassStrong,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.borderGlow),
                boxShadow: AppColors.navShadow,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: currentIndex == i,
                        badge: items[i].label == 'Alerts' || items[i].label == 'Inbox' ? unread : 0,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap, this.badge = 0});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected ? AppColors.orangeGlow : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  color: selected ? Colors.white : AppColors.muted,
                  size: 22,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.muted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBell,
    this.onAvatar,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          const BrandMark(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'StaffPro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                Text(
                  subtitle ?? 'Manage People. Grow Business.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassStrong,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: IconButton(
                  onPressed: onBell ?? () => context.push(_notifyRoute(user?.role)),
                  icon: Badge(
                    isLabelVisible: app.unreadCount > 0,
                    backgroundColor: AppColors.primary,
                    label: Text('${app.unreadCount}'),
                    child: const Icon(Icons.notifications_none_rounded, color: AppColors.text),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAvatar ?? () => context.push(_profileRoute(user?.role)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.55), width: 2),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  Formatters.initials(user?.fullName ?? 'U'),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _notifyRoute(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return '/sa/notifications';
      case UserRole.businessAdmin:
        return '/ba/notifications';
      case UserRole.manager:
        return '/mg/notifications';
      default:
        return '/emp/notifications';
    }
  }

  String _profileRoute(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return '/sa/profile';
      case UserRole.businessAdmin:
        return '/ba/profile';
      case UserRole.manager:
        return '/mg/profile';
      default:
        return '/emp/profile';
    }
  }
}

class BranchSelectorBar extends StatelessWidget {
  const BranchSelectorBar({super.key, this.allowAll = true});
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser;
    if (user == null) return const SizedBox.shrink();
    if (user.role == UserRole.manager || user.role == UserRole.employee) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: AppChip(text: app.branchName(user.branchId), icon: Icons.storefront_outlined),
      );
    }
    final branches = app.visibleBranches().where((b) => b.status == EntityStatus.active).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassStrong,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderGlow),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: app.selectedBranchId,
              dropdownColor: AppColors.navySoft,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.storefront_outlined, color: AppColors.primary),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
              items: [
                if (allowAll) const DropdownMenuItem<String?>(value: null, child: Text('All Branches')),
                ...branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
              ],
              onChanged: (v) => app.setSelectedBranch(v),
            ),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text))),
        ],
      ),
    );
  }
}
