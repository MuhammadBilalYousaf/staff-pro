import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
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
    final subtitle = user == null ? null : (biz.isEmpty || biz == '—' ? roleLabel(user.role) : '${roleLabel(user.role)} · $biz');
    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _history.length <= 1) return;
        _restoringTab = true;
        setState(() => _history.removeLast());
        navigationShell.goBranch(_history.last);
      },
      child: Scaffold(
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: AppColors.navy.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: navigationShell.currentIndex == i,
                      badge: items[i].label == 'Alerts' || items[i].label == 'Inbox' ? app.unreadCount : 0,
                      onTap: () => _selectTab(i),
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
    final color = selected ? AppColors.primary : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, color: color, size: 24),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: onBell ?? () => context.push(_notifyRoute(user?.role)),
            icon: Badge(
              isLabelVisible: app.unreadCount > 0,
              label: Text('${app.unreadCount}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          GestureDetector(
            onTap: onAvatar ?? () => context.push(_profileRoute(user?.role)),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.washStrong,
              child: Text(
                Formatters.initials(user?.fullName ?? 'U'),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      child: DropdownButtonFormField<String?>(
        // ignore: deprecated_member_use
        value: app.selectedBranchId,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.storefront_outlined),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          if (allowAll) const DropdownMenuItem<String?>(value: null, child: Text('All branches')),
          ...branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
        ],
        onChanged: (v) => app.setSelectedBranch(v),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
