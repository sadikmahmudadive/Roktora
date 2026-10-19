import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/shell_home.dart';

class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final async = ref.watch(requestProvider(id));
    final repo = ref.read(repositoryProvider);
    final r = async.value;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: c.surface0, leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: async.isLoading ? const CircularProgressIndicator() : const Text('This request is no longer available.')),
      );
    }
    final mine = r.committedUids.contains(repo.uid);
    final critical = r.urgency == Urgency.critical;
    final stripBg = critical ? c.bgDanger : r.urgency == Urgency.urgent ? c.bgWarning : c.surface2;
    final stripFg = urgencyText(c, r.urgency);
    final remaining = (r.bagsNeeded - r.committed).clamp(0, r.bagsNeeded);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(children: [
              CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop()),
              const Spacer(),
              CircleIconButton(icon: TablerIcons.share, label: 'Share', onPressed: () {}),
              const SizedBox(width: 4),
              CircleIconButton(icon: TablerIcons.flag, label: 'Report', onPressed: () => _report(context)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: stripBg, borderRadius: BorderRadius.circular(RRadius.base)),
                child: Row(children: [
                  Icon(critical ? TablerIcons.alert_triangle : TablerIcons.clock, color: stripFg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${urgencyLabel(r.urgency)} · needed by ${DateFormat('h:mm a').format(r.deadline)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: stripFg)),
                      Text('${timeLeft(r.deadline)} left', style: TextStyle(fontSize: 13, color: stripFg)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    BloodPill(r.bloodGroup, role: critical ? PillRole.danger : PillRole.warning, height: 28, size: 14),
                    const SizedBox(width: 8),
                    Text('Whole blood · ${r.bagsNeeded} bag${r.bagsNeeded == 1 ? '' : 's'}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 8),
                  Text(r.title, style: AppTheme.display(context, size: 28)),
                  const SizedBox(height: 8),
                  if (r.verified)
                    const VerifiedBadge()
                  else
                    Row(children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.borderStronger)), child: const Icon(TablerIcons.user, size: 11)),
                      const SizedBox(width: 8),
                      Text('Individual request${r.postedBy.isEmpty ? '' : ' · posted by ${r.postedBy}'} · not verified', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ]),
                ]),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${r.committed} of ${r.bagsNeeded} donors committed', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('$remaining more needed', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (var i = 0; i < r.bagsNeeded.clamp(1, 12); i++)
                      Expanded(child: Container(height: 6, margin: EdgeInsets.only(right: i == r.bagsNeeded.clamp(1, 12) - 1 ? 0 : 4), decoration: BoxDecoration(color: i < r.committed ? c.fillBrand : c.progressTrack, borderRadius: BorderRadius.circular(99)))),
                  ]),
                ]),
              ),
              if (mine) ...[
                const SizedBox(height: 16),
                InfoBanner('Commitment sent. The requester has been notified and can message you.', icon: TablerIcons.circle_check, bg: c.bgSuccess, fg: c.textSuccess),
              ],
              const SizedBox(height: 16),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _InfoRow(TablerIcons.building_hospital, r.place, r.note.isEmpty ? null : r.note),
                  _InfoRow(TablerIcons.walk, '${r.distanceKm} km · ${(r.distanceKm * 12).round()} min walk', '${(r.distanceKm * 6.5).round()} min by rickshaw', divider: true),
                  _InfoRow(TablerIcons.shield_check, r.verified ? 'Verified by the hospital' : 'Screened by Roktora',
                      r.verified ? 'Posted by blood bank staff' : 'Admission confirmed by phone before publishing', divider: true),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Never pay or accept money for blood. Report anyone who asks.', style: TextStyle(fontSize: 12, color: c.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border)), color: c.surface0),
            child: Row(children: [
              CircleIconButton(icon: TablerIcons.message_circle, size: 52, label: 'Message requester', filled: false, onPressed: () => context.push('/chat/${r.id}')),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(mine ? 'Cancel commitment' : 'Commit to donate', height: 52, outlined: mine, danger: mine, onPressed: () async {
                  await repo.setCommitment(r.id, !mine);
                  if (!mine && context.mounted) context.push('/consent/${r.id}');
                }),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _report(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: context.rc.surface3,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final reason in ['Asked for money', 'Looks fake or duplicate', 'Wrong details'])
              ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks. Our team will review this request.')));
                },
              ),
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.sub, {this.divider = false});
  final IconData icon;
  final String title;
  final String? sub;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
      child: Row(children: [
        Icon(icon, size: 20, color: c.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sub != null) Text(sub!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  void _send(String t) {
    if (t.trim().isEmpty) return;
    ref.read(repositoryProvider).sendMessage(widget.requestId, t.trim());
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final me = ref.read(repositoryProvider).uid;
    final req = ref.watch(requestProvider(widget.requestId)).value;
    final msgs = ref.watch(messagesProvider(widget.requestId)).value ?? const <ChatMessage>[];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            height: 60, padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            child: Row(children: [
              CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop()),
              const SizedBox(width: 8),
              DonorAvatar((req?.postedBy.isNotEmpty ?? false) ? req!.postedBy.substring(0, 1) : 'R', size: 36),
              const SizedBox(width: 8),
              Expanded(child: Text(req?.postedBy.isNotEmpty == true ? req!.postedBy : (req?.place ?? 'Requester'), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          if (req != null)
            InkWell(
              onTap: () => context.push('/request/${req.id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: c.surface2, border: Border(left: BorderSide(color: urgencyColor(c, req.urgency), width: 2), bottom: BorderSide(color: c.border))),
                child: Row(children: [
                  BloodPill(req.bloodGroup, role: roleForGroup(req.bloodGroup), height: 22, size: 12),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${req.place} · by ${DateFormat('h a').format(req.deadline)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Text('${req.committed} of ${req.bagsNeeded}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Icon(TablerIcons.chevron_right, size: 18, color: c.textMuted),
                ]),
              ),
            ),
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
                  child: Text('Phone numbers stay hidden unless you share them', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ),
              ),
              for (final m in msgs)
                Align(
                  alignment: m.fromUid == me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(crossAxisAlignment: m.fromUid == me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: m.fromUid == me ? c.fillBrand : c.surface1, borderRadius: BorderRadius.circular(20),
                        border: m.fromUid == me ? null : Border.all(color: c.border),
                      ),
                      child: Text(m.text, style: TextStyle(fontSize: 14, color: m.fromUid == me ? c.onFill : c.textPrimary)),
                    ),
                    Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 0), child: Text(DateFormat('h:mm a').format(m.sentAt), style: TextStyle(fontSize: 11, color: c.textMuted))),
                  ]),
                ),
            ]),
          ),
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), children: [
              for (final q in ["I'm on my way", 'Running 10 min late', "I've arrived"])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(label: Text(q), onPressed: () => _send(q), shape: const StadiumBorder(), backgroundColor: c.surface1, side: BorderSide(color: c.borderStrong)),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(children: [
              CircleIconButton(icon: TablerIcons.map_pin_share, label: 'Share location', filled: false, onPressed: () {}),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl, onSubmitted: _send, textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Write a message', filled: true, fillColor: c.surface1, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base), borderSide: BorderSide(color: c.borderStronger)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base), borderSide: BorderSide(color: c.borderStronger)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(color: c.fillBrand, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: () => _send(_ctrl.text), child: SizedBox(width: 44, height: 44, child: Icon(TablerIcons.send, size: 18, color: c.onFill)))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Chats tab: one thread per request the user committed to.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(repositoryProvider).uid;
    final mine = (ref.watch(requestsProvider).value ?? const <BloodRequest>[]).where((r) => r.committedUids.contains(uid)).toList();
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavClearance), children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text('Chats', style: AppTheme.display(context, size: 26))),
        if (mine.isEmpty)
          const SurfaceCard(child: EmptyState(icon: TablerIcons.message_circle, title: 'No chats yet', message: 'Commit to a request and its chat shows up here.'))
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < mine.length; i++) UrgencyRowChat(mine[i], divider: i > 0),
            ]),
          ),
      ]),
    );
  }
}

class UrgencyRowChat extends StatelessWidget {
  const UrgencyRowChat(this.r, {super.key, this.divider = false});
  final BloodRequest r;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return InkWell(
      onTap: () => context.push('/chat/${r.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
        child: Row(children: [
          BloodPill(r.bloodGroup, role: roleForGroup(r.bloodGroup), height: 24, size: 12),
          const SizedBox(width: 12),
          Expanded(child: Text('${r.title} · ${r.place}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          Icon(TablerIcons.chevron_right, size: 18, color: c.textMuted),
        ]),
      ),
    );
  }
}

class PostRequestScreen extends ConsumerStatefulWidget {
  const PostRequestScreen({super.key});
  @override
  ConsumerState<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends ConsumerState<PostRequestScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  String _group = 'O−';
  int _bags = 1;
  Urgency _urgency = Urgency.urgent;
  bool _busy = false;

  bool get _valid => _title.text.trim().length > 3 && _place.text.trim().length > 2;

  Future<void> _post() async {
    final repo = ref.read(repositoryProvider);
    final name = ref.read(profileProvider).value?.publicName ?? '';
    setState(() => _busy = true);
    final hours = switch (_urgency) { Urgency.critical => 6, Urgency.urgent => 24, Urgency.routine => 72 };
    await repo.postRequest(BloodRequest(
      id: '', bloodGroup: _group, title: _title.text.trim(), place: _place.text.trim(), distanceKm: 0, bagsNeeded: _bags, committed: 0,
      urgency: _urgency, deadline: DateTime.now().add(Duration(hours: hours)), postedBy: name,
    ));
    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request posted. We screen individual requests before alerting donors.')));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.x, label: 'Close', onPressed: () => context.pop()))),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
              const ScreenHeading('Post a request', subtitle: 'Individual requests are screened by Roktora before donors are alerted.'),
              const SizedBox(height: 24),
              const Text('What is it for?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _title, onChanged: (_) => setState(() {}), decoration: _dec(c, 'e.g. 2 bags for surgery')),
              const SizedBox(height: 18),
              const Text('Hospital or place', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _place, onChanged: (_) => setState(() {}), decoration: _dec(c, 'e.g. Dhanmondi General')),
              const SizedBox(height: 18),
              const Text('Blood group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in bloodGroups)
                  ChoiceChip(label: Text(g), selected: g == _group, showCheckmark: false, onSelected: (_) => setState(() => _group = g), shape: const StadiumBorder(),
                      selectedColor: c.bgBrand, side: BorderSide(color: g == _group ? c.fillBrand : c.borderStrong)),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Text('Bags needed', style: TextStyle(fontWeight: FontWeight.w600))),
                CircleIconButton(icon: TablerIcons.minus, label: 'Fewer', onPressed: _bags > 1 ? () => setState(() => _bags--) : null),
                SizedBox(width: 48, child: Center(child: Text('$_bags', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
                CircleIconButton(icon: TablerIcons.plus, label: 'More', onPressed: _bags < 10 ? () => setState(() => _bags++) : null),
              ]),
              const SizedBox(height: 18),
              const Text('How soon?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<Urgency>(
                segments: const [
                  ButtonSegment(value: Urgency.critical, label: Text('Critical')),
                  ButtonSegment(value: Urgency.urgent, label: Text('Today')),
                  ButtonSegment(value: Urgency.routine, label: Text('This week')),
                ],
                selected: {_urgency}, showSelectedIcon: false, onSelectionChanged: (s) => setState(() => _urgency = s.first),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), child: PillButton(_busy ? 'Posting…' : 'Post request', onPressed: _valid && !_busy ? _post : null)),
        ]),
      ),
    );
  }

  InputDecoration _dec(RColors c, String hint) => InputDecoration(
        hintText: hint, filled: true, fillColor: c.surface1, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.fillBrand, width: 1.5)),
      );
}
