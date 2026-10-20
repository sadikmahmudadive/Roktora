import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);
  final String path, label;
  final IconData icon;
}

const _items = [
  _NavItem('/admin', 'Dashboard', TablerIcons.layout_dashboard),
  _NavItem('/admin/inventory', 'Inventory', TablerIcons.droplet),
  _NavItem('/admin/requests', 'Requests', TablerIcons.urgent),
  _NavItem('/admin/checkin', 'Check-in', TablerIcons.scan),
  _NavItem('/admin/donors', 'Donors', TablerIcons.users),
  _NavItem('/admin/reports', 'Reports', TablerIcons.chart_bar),
  _NavItem('/admin/profile', 'Hospital profile', TablerIcons.building_hospital),
];

/// Frame for every dashboard screen: a sidebar on wide screens, a drawer on narrow ones.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const double breakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider);
    return access.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _NoAccess(),
      data: (a) {
        if (a == null) return const _NoAccess();
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= breakpoint;
          final current = _items.lastWhere((i) => location == i.path || (i.path != '/admin' && location.startsWith(i.path)), orElse: () => _items.first);
          if (wide) {
            return Scaffold(
              body: Row(children: [
                SizedBox(width: 256, child: _Sidebar(location: location, access: a)),
                VerticalDivider(width: 1, color: context.rc.border),
                Expanded(child: child),
              ]),
            );
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: context.rc.surface0,
              surfaceTintColor: Colors.transparent,
              title: Text(current.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            drawer: Drawer(backgroundColor: context.rc.surface1, child: _Sidebar(location: location, access: a, inDrawer: true)),
            body: child,
          );
        });
      },
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.access, this.inDrawer = false});
  final String location;
  final AdminAccess access;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final hospital = ref.watch(hospitalProvider).value;
    final requests = ref.watch(hospitalRequestsProvider).value ?? const [];
    final inventory = ref.watch(inventoryProvider).value ?? const <InventoryRow>[];
    final lowCount = inventory.where((r) => r.level != StockLevel.healthy).length;
    final openCount = requests.where((r) => r.isOpen).length;

    String badge(_NavItem i) => switch (i.path) {
          '/admin/inventory' => lowCount > 0 ? '$lowCount low' : '',
          '/admin/requests' => openCount > 0 ? '$openCount' : '',
          _ => '',
        };

    return Container(
      color: c.surface1,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              const RoktoraMark(height: 26),
              const SizedBox(width: 10),
              const Text('Roktora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -.3)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface0, borderRadius: BorderRadius.circular(RRadius.base), border: Border.all(color: c.border)),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)), child: Icon(TablerIcons.building_hospital, size: 18, color: c.textSecondary)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hospital?.name ?? 'Your hospital', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (hospital?.verified ?? false) const VerifiedBadge(label: 'Verified') else Text('Not verified', style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ]),
                ),
              ]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final i in _items)
                Builder(builder: (context) {
                  final selected = location == i.path || (i.path != '/admin' && location.startsWith(i.path));
                  final b = badge(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Semantics(
                      button: true, selected: selected, label: i.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(RRadius.base),
                        onTap: () {
                          if (inDrawer) Navigator.of(context).pop();
                          context.go(i.path);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: selected ? c.surface2 : null, borderRadius: BorderRadius.circular(RRadius.base)),
                          child: Row(children: [
                            Icon(i.icon, size: 19, color: selected ? c.textPrimary : c.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(i.label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? c.textPrimary : c.textSecondary))),
                            if (b.isNotEmpty) Text(b, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: i.path == '/admin/inventory' ? c.textDanger : c.textMuted)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                DonorAvatar(access.name.isEmpty ? 'S' : access.name.substring(0, 1), size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(access.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(access.isAdmin ? 'Admin' : 'Staff', style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Toggle theme',
                  icon: Icon(Theme.of(context).brightness == Brightness.dark ? TablerIcons.sun : TablerIcons.moon, size: 19),
                  onPressed: () => ref.read(themeModeProvider.notifier).set(Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AdminButton('Donor app', outlined: true, icon: TablerIcons.arrow_left, onPressed: () => context.go('/home'))),
                const SizedBox(width: 8),
                Expanded(child: AdminButton('Sign out', outlined: true, icon: TablerIcons.logout, onPressed: () => ref.read(repositoryProvider).signOut())),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NoAccess extends ConsumerWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final uid = ref.read(repositoryProvider).uid ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 64, height: 64, decoration: BoxDecoration(color: c.bgWarning, borderRadius: BorderRadius.circular(20)), child: Icon(TablerIcons.lock, size: 30, color: c.textWarning)),
                const SizedBox(height: 20),
                Text('This account isn\'t linked to a hospital', style: AppTheme.display(context, size: 28)),
                const SizedBox(height: 12),
                Text(
                  'The dashboard is for verified hospital staff. A Roktora admin links you in the Firebase console by setting role (admin or staff) and hospitalId on your record in the accounts collection.',
                  style: TextStyle(color: c.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (uid.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account ID copied.')));
                    },
                    borderRadius: BorderRadius.circular(RRadius.base),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(RRadius.base)),
                      child: Row(children: [
                        Expanded(child: Text(uid, style: AppTheme.mono(context, size: 12, color: c.textPrimary))),
                        const SizedBox(width: 8),
                        Icon(TablerIcons.copy, size: 16, color: c.textMuted),
                      ]),
                    ),
                  ),
                const SizedBox(height: 24),
                PillButton('Back to the app', height: 52, onPressed: () => context.go('/home')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
