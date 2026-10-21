import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../permissions/permissions_screen.dart' show PermissionReminder;
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../requests/chat_screens.dart' show ChatUnreadBadge;

/// Bottom space tab screens reserve so the floating nav never covers content.
const double kNavClearance = 96;

/// Hosts the tab pages and a collapsible floating nav. It rests as a round
/// blood-drop button, and expands into the tab bar when tapped or when the
/// page is scrolled to the bottom.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (TablerIcons.home, 'Home'),
    (TablerIcons.map_2, 'Map'),
    (TablerIcons.message_circle, 'Chats'),
    (TablerIcons.id_badge_2, 'Passport'),
    (TablerIcons.user_circle, 'Profile'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _expanded = false;

  /// True while the user opened the bar by tapping (as opposed to reaching the bottom).
  bool _pinnedOpen = false;

  void _setExpanded(bool v, {bool pinned = false}) {
    if (_expanded == v && _pinnedOpen == (v && pinned)) return;
    setState(() {
      _expanded = v;
      _pinnedOpen = v && pinned;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final m = n.metrics;
    if (m.maxScrollExtent <= 0) return false; // page doesn't scroll
    final atBottom = m.pixels >= m.maxScrollExtent - 24;
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle && _pinnedOpen && !atBottom) {
      _setExpanded(false); // scrolling away dismisses a tapped-open bar
    } else if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      if (atBottom && !_expanded) {
        HapticFeedback.selectionClick();
        _setExpanded(true);
      } else if (!atBottom && _expanded && !_pinnedOpen) {
        _setExpanded(false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final shell = widget.shell;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dur = Duration(milliseconds: reduce ? 0 : 320);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: shell)),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LayoutBuilder(builder: (context, box) {
                const collapsed = 60.0;
                final full = box.maxWidth;
                return Align(
                  alignment: Alignment.bottomRight,
                  child: AnimatedContainer(
                    duration: dur,
                    curve: Curves.easeOutCubic,
                    width: _expanded ? full : collapsed,
                    height: _expanded ? 68 : collapsed,
                    decoration: BoxDecoration(
                      color: _expanded ? c.surface1 : c.fillBrand,
                      borderRadius: BorderRadius.circular(RRadius.pill),
                      border: Border.all(color: _expanded ? c.border : Colors.transparent),
                      boxShadow: [
                        BoxShadow(
                          color: (_expanded ? Colors.black : c.fillBrand).withValues(alpha: _expanded ? .10 : .35),
                          blurRadius: 24, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(alignment: Alignment.center, children: [
                      // Collapsed state: the drop.
                      IgnorePointer(
                        ignoring: _expanded,
                        child: AnimatedOpacity(
                          opacity: _expanded ? 0 : 1,
                          duration: Duration(milliseconds: reduce ? 0 : 160),
                          child: Semantics(
                            button: true, label: 'Open navigation',
                            child: Pressable(
                              scale: .9,
                              onTap: () => _setExpanded(true, pinned: true),
                              child: const SizedBox(width: collapsed, height: collapsed, child: Center(child: RoktoraMark(height: 28, color: Colors.white))),
                            ),
                          ),
                        ),
                      ),
                      // Expanded state: laid out at full width so it never squeezes mid-animation.
                      IgnorePointer(
                        ignoring: !_expanded,
                        child: AnimatedOpacity(
                          opacity: _expanded ? 1 : 0,
                          duration: Duration(milliseconds: reduce ? 0 : 200),
                          curve: _expanded ? const Interval(.4, 1) : Curves.easeIn,
                          child: OverflowBox(
                            minWidth: full, maxWidth: full, minHeight: 68, maxHeight: 68,
                            child: _tabBar(c, full),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabBar(RColors c, double width) {
    final shell = widget.shell;
    final w = (width - 12) / AppShell._tabs.length;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 56,
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: shell.currentIndex * w, width: w, top: 0, bottom: 0,
            child: Container(decoration: BoxDecoration(color: c.bgBrand, borderRadius: BorderRadius.circular(RRadius.pill))),
          ),
          Row(children: [
            for (var i = 0; i < AppShell._tabs.length; i++)
              Expanded(
                child: Semantics(
                  button: true, selected: i == shell.currentIndex, label: AppShell._tabs[i].$2,
                  child: Pressable(
                    scale: .94,
                    onTap: () {
                      shell.goBranch(i, initialLocation: i == shell.currentIndex);
                      _setExpanded(false); // tuck away after choosing a tab
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      (AppShell._tabs[i].$2 == 'Chats' ? ChatUnreadBadge(child: Icon(AppShell._tabs[i].$1, size: 22, color: i == shell.currentIndex ? c.textBrand : c.textMuted)) : Icon(AppShell._tabs[i].$1, size: 22, color: i == shell.currentIndex ? c.textBrand : c.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        AppShell._tabs[i].$2,
                        style: TextStyle(fontSize: 11, fontWeight: i == shell.currentIndex ? FontWeight.w600 : FontWeight.w500, color: i == shell.currentIndex ? c.textBrand : c.textMuted),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

Color urgencyColor(RColors c, Urgency u) => switch (u) { Urgency.critical => c.borderDanger, Urgency.urgent => c.borderWarning, Urgency.routine => c.border };

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final profile = ref.watch(profileProvider).value;
    final requests = ref.watch(requestsProvider);
    final mine = profile?.bloodGroup;
    final list = [...(requests.value ?? <BloodRequest>[])]
      ..sort((a, b) => a.urgency.index != b.urgency.index ? a.urgency.index - b.urgency.index : a.distanceKm.compareTo(b.distanceKm));
    final top = list.isEmpty ? null : list.first;
    final rest = list.skip(1).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(requestsProvider),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavClearance), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile?.area ?? '', style: TextStyle(fontSize: 13, color: c.textMuted)),
                  Text('${_greeting()}${profile == null ? '' : ', ${profile.name.split(' ').first}'}', style: AppTheme.display(context, size: 26)),
                ]),
              ),
              Stack(clipBehavior: Clip.none, children: [
                CircleIconButton(icon: TablerIcons.bell, label: 'Messages', onPressed: () => context.push('/inbox')),
                if ((ref.watch(inboxProvider).value ?? const []).any((m) => !m.read))
                  Positioned(right: 2, top: 2, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: c.fillBrand, shape: BoxShape.circle, border: Border.all(color: c.surface0, width: 2)))),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (requests.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InfoBanner("You're offline or can't reach the server. Pull down to retry.", icon: TablerIcons.cloud_off, bg: c.surface2, fg: c.textSecondary),
            ),
          const PermissionReminder(),
          if (profile != null) FadeSlideIn(child: _DonorTile(profile)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Near you', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              GestureDetector(onTap: () => context.go('/map'), child: Text('See map', style: TextStyle(fontSize: 13, color: c.textAccent, fontWeight: FontWeight.w600))),
            ]),
          ),
          if (requests.isLoading && list.isEmpty) const _HomeSkeleton(),
          if (!requests.isLoading && list.isEmpty)
            SurfaceCard(
              child: EmptyState(
                icon: TablerIcons.heart_handshake,
                title: 'All quiet near you',
                message: "No open requests right now. We'll alert you when someone needs ${mine ?? 'your blood group'}.",
              ),
            ),
          if (top != null) FadeSlideIn(index: 1, child: _TopRequestCard(top)),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < rest.length; i++) UrgencyRow(rest[i], divider: i > 0),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/request/new'),
              icon: const Icon(TablerIcons.plus, size: 18),
              label: const Text('Post a request for someone'),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: c.textPrimary, side: BorderSide(color: c.borderStrong)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DonorTile extends ConsumerWidget {
  const _DonorTile(this.p);
  final DonorProfile p;
  Widget _eligibilityChip(BuildContext context, RColors c) {
    Widget chip(Color bg, Color fg, IconData icon, String text, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 22, padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: fg), const SizedBox(width: 4),
              Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
            ]),
          ),
        );
    if (!p.eligible) {
      return chip(c.bgWarning, c.textWarning, TablerIcons.clock_pause, 'Retake check', onTap: () => context.push('/eligibility'));
    }
    final days = p.daysUntilEligible;
    if (days > 0) return chip(c.bgWarning, c.textWarning, TablerIcons.clock, 'Eligible in $days day${days == 1 ? '' : 's'}');
    return chip(c.bgSuccess, c.textSuccess, TablerIcons.circle_check, 'Eligible now');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final last = p.lastDonation;
    return SurfaceCard(
      child: Column(children: [
        Row(children: [
          DonorAvatar(p.initials, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (p.bloodGroup != null) ...[BloodPill(p.bloodGroup!, role: roleForGroup(p.bloodGroup!), height: 22, size: 12), const SizedBox(width: 8)],
                _eligibilityChip(context, c),
              ]),
              const SizedBox(height: 4),
              Text('${p.donations} donation${p.donations == 1 ? '' : 's'}${last == null ? '' : ' · last on ${DateFormat('d MMM').format(last)}'}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Available for alerts', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${p.bloodGroup ?? 'Matching'} requests within 5 km', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
          RSwitch(value: p.available, onChanged: (v) => ref.read(repositoryProvider).setAvailable(v), label: 'Available for alerts'),
        ]),
      ]),
    );
  }
}

class _TopRequestCard extends StatelessWidget {
  const _TopRequestCard(this.r);
  final BloodRequest r;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final critical = r.urgency == Urgency.critical;
    return SurfaceCard(
      stripe: urgencyColor(c, r.urgency),
      onTap: () => context.push('/request/${r.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BloodPill(r.bloodGroup, role: critical ? PillRole.danger : PillRole.warning, height: 24, size: 12),
          const SizedBox(width: 8),
          Ticker(builder: (_) => Text('${urgencyLabel(r.urgency)} · ${timeLeft(r.deadline)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: urgencyText(c, r.urgency)))),
          const Spacer(),
          Text('${r.distanceKm} km', style: TextStyle(fontSize: 12, color: c.textMuted)),
        ]),
        const SizedBox(height: 12),
        Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        Text('${r.place} · ${(r.distanceKm * 12).round()} min walk', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 12),
        RProgress(r.progress),
        const SizedBox(height: 12),
        PillButton('View request', height: 44, onPressed: () => context.push('/request/${r.id}')),
      ]),
    );
  }
}

String urgencyLabel(Urgency u) => switch (u) { Urgency.critical => 'Critical', Urgency.urgent => 'Urgent', Urgency.routine => 'Routine' };
Color urgencyText(RColors c, Urgency u) => switch (u) { Urgency.critical => c.textDanger, Urgency.urgent => c.textWarning, Urgency.routine => c.textSecondary };

/// Flat list row with a 2px urgency stripe.
class UrgencyRow extends StatelessWidget {
  const UrgencyRow(this.r, {super.key, this.divider = false});
  final BloodRequest r;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return InkWell(
      onTap: () => context.push('/request/${r.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: urgencyColor(c, r.urgency), width: 2), top: divider ? BorderSide(color: c.border) : BorderSide.none)),
        child: Row(children: [
          BloodPill(r.bloodGroup, role: r.urgency == Urgency.routine ? PillRole.neutral : (r.urgency == Urgency.critical ? PillRole.danger : PillRole.warning), height: 24, size: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${r.place} · ${r.distanceKm} km', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
          Text(urgencyLabel(r.urgency), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: urgencyText(c, r.urgency))),
        ]),
      ),
    );
  }
}


class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => const Column(children: [
        SkeletonBox(height: 168, radius: 22),
        SizedBox(height: 12),
        SkeletonBox(height: 64, radius: 22),
        SizedBox(height: 8),
        SkeletonBox(height: 64, radius: 22),
      ]);
}
