import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

/// Messages hospitals have sent to this donor.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final messages = ref.watch(inboxProvider).value ?? const [];
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home'))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text('Messages', style: AppTheme.display(context, size: 30))),
          if (messages.isEmpty)
            const SurfaceCard(child: EmptyState(icon: TablerIcons.mail, title: 'No messages yet', message: 'Hospitals you donate to can send you updates here.'))
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, m) in messages.indexed)
                  InkWell(
                    onTap: () {
                      if (!m.read) ref.read(repositoryProvider).markInboxRead(m.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: m.read ? null : c.bgBrand, border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: c.bgAccent, borderRadius: BorderRadius.circular(12)), child: Icon(TablerIcons.building_hospital, size: 20, color: c.textAccent)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(m.from, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text(DateFormat('d MMM, h:mm a').format(m.at), style: TextStyle(fontSize: 11, color: c.textMuted)),
                            ]),
                            const SizedBox(height: 4),
                            Text(m.body, style: TextStyle(color: c.textSecondary, height: 1.4)),
                          ]),
                        ),
                        if (!m.read) Container(margin: const EdgeInsets.only(left: 8, top: 6), width: 8, height: 8, decoration: BoxDecoration(color: c.fillBrand, shape: BoxShape.circle)),
                      ]),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
