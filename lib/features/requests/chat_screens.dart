import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/shell_home.dart';
import '../location/location_picker.dart';

// ---------------------------------------------------------------------------------------------------------------
// Shared helpers

/// A message from someone else that this user has not opened yet.
bool _isUnread(ChatMessage? last, DateTime? readAt, String? me) =>
    last != null &&
    last.fromUid != me &&
    !last.pending &&
    (readAt == null || last.sentAt.isAfter(readAt));

/// Requests that have a chat for this user: ones they committed to and ones they posted.
final chatThreadsProvider = Provider<List<BloodRequest>>((ref) {
  final uid = ref.watch(repositoryProvider).uid;
  final committed =
      (ref.watch(requestsProvider).value ?? const <BloodRequest>[]).where(
        (r) => r.committedUids.contains(uid),
      );
  final posted = ref.watch(myRequestsProvider).value ?? const <BloodRequest>[];
  return {
    for (final r in [...committed, ...posted]) r.id: r,
  }.values.toList();
});

/// How many threads have something new, for the badge on the Chats tab.
final unreadChatsProvider = Provider<int>((ref) {
  final me = ref.watch(repositoryProvider).uid;
  var n = 0;
  for (final r in ref.watch(chatThreadsProvider)) {
    final last = ref.watch(lastMessageProvider(r.id)).value;
    final readAt = ref.watch(chatReadProvider(r.id)).value;
    if (_isUnread(last, readAt, me)) {
      n++;
    }
  }
  return n;
});

/// Overlays a small unread count on the Chats tab icon.
class ChatUnreadBadge extends ConsumerWidget {
  const ChatUnreadBadge({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(unreadChatsProvider);
    if (n == 0) return child;
    final c = context.rc;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -5,
          child: Semantics(
            label: '$n unread chats',
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.fillBrand,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: c.onFill,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(d.year == now.year ? 'EEE, d MMM' : 'd MMM y').format(d);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Future<void> _openInMaps(BuildContext context, double lat, double lng) async {
  final ok = await launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open Maps on this device.")),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// One request's chat

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _maxLength = 1000;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _stick =
      true; // follow new messages only while the reader is at the bottom
  String? _readKey;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      _stick = _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _failed(String text) {
    if (!mounted) return;
    if (_ctrl.text.isEmpty) _ctrl.text = text;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't send. This chat is only open while the request is open.",
        ),
      ),
    );
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() {});
    _stick = true;
    ref
        .read(repositoryProvider)
        .sendMessage(widget.requestId, text)
        .catchError((_) => _failed(text));
  }

  Future<void> _shareLocation(BloodRequest? req) async {
    final r = await pickLocation(
      context,
      title: 'Share a location',
      confirmLabel: 'Send location',
      initial: (req?.hasLocation ?? false) ? LatLng(req!.lat!, req.lng!) : null,
      hint: 'Pick where you are or where to meet. Only people in this chat see it.',
    );
    if (r == null || !mounted) return;
    _stick = true;
    ref
        .read(repositoryProvider)
        .sendLocation(widget.requestId, r.lat, r.lng, r.label)
        .catchError((_) => _failed(''));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final repo = ref.read(repositoryProvider);
    final me = repo.uid;
    final req = ref.watch(requestProvider(widget.requestId)).value;
    final async = ref.watch(messagesProvider(widget.requestId));
    final msgs = async.value ?? const <ChatMessage>[];
    final denied = async.hasError && msgs.isEmpty; // not in this chat
    final open = req?.isOpen ?? true;

    // Follow new messages and mark the thread read.
    final key = '${msgs.length}:${msgs.isEmpty ? '' : msgs.last.id}';
    if (key != _readKey) {
      final first = _readKey == null;
      _readKey = key;
      if (!first &&
          msgs.length > _count &&
          (_stick || msgs.last.fromUid == me)) {
        _toBottom();
      }
      if (first && msgs.isNotEmpty) _toBottom(animate: false);
      _count = msgs.length;
      if (msgs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => repo.markChatRead(widget.requestId).catchError((_) {}),
        );
      }
    }

    final title = req == null
        ? 'Chat'
        : (req.title.isNotEmpty ? req.title : req.place);
    final sub = req == null
        ? ''
        : '${req.place} · ${req.committed} donor${req.committed == 1 ? '' : 's'} committed';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: TablerIcons.arrow_left,
                    label: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  DonorAvatar(
                    (req?.postedBy.isNotEmpty ?? false)
                        ? req!.postedBy.substring(0, 1)
                        : 'R',
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (req != null)
              InkWell(
                onTap: () => context.push('/request/${req.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    border: Border(
                      left: BorderSide(
                        color: urgencyColor(c, req.urgency),
                        width: 2,
                      ),
                      bottom: BorderSide(color: c.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      BloodPill(
                        req.bloodGroup,
                        role: roleForGroup(req.bloodGroup),
                        height: 22,
                        size: 12,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          open
                              ? 'Needed by ${DateFormat('h a').format(req.deadline)}'
                              : 'Closed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${req.committed} of ${req.bagsNeeded}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                      Icon(
                        TablerIcons.chevron_right,
                        size: 18,
                        color: c.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _messageList(context, c, async, msgs, me)),
            if (open && !denied)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  children: [
                    for (final q in [
                      "I'm on my way",
                      'Running 10 min late',
                      "I've arrived",
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(q),
                          onPressed: () => _send(q),
                          shape: const StadiumBorder(),
                          backgroundColor: c.surface1,
                          side: BorderSide(color: c.borderStrong),
                        ),
                      ),
                  ],
                ),
              )
            else if (!open)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: c.surface2,
                child: Row(
                  children: [
                    Icon(TablerIcons.lock, size: 16, color: c.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This request is closed, so the chat is read-only.',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if (open && !denied)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CircleIconButton(
                      icon: TablerIcons.map_pin_share,
                      label: 'Share location',
                      filled: false,
                      onPressed: () => _shareLocation(req),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onChanged: (_) => setState(() {}),
                        minLines: 1,
                        maxLines: 4,
                        maxLength: _maxLength,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Write a message',
                          counterText: '',
                          filled: true,
                          fillColor: c.surface1,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(RRadius.base),
                            borderSide: BorderSide(color: c.borderStronger),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(RRadius.base),
                            borderSide: BorderSide(color: c.borderStronger),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Send message',
                      child: Material(
                        color: _ctrl.text.trim().isEmpty
                            ? c.surface3
                            : c.fillBrand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _ctrl.text.trim().isEmpty
                              ? null
                              : () => _send(_ctrl.text),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              TablerIcons.send,
                              size: 18,
                              color: _ctrl.text.trim().isEmpty
                                  ? c.textMuted
                                  : c.onFill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageList(
    BuildContext context,
    RColors c,
    AsyncValue<List<ChatMessage>> async,
    List<ChatMessage> msgs,
    String? me,
  ) {
    if (async.hasError && msgs.isEmpty) {
      // Scrollable so it still fits when the keyboard or a small screen leaves little room.
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: const EmptyState(
            icon: TablerIcons.lock,
            title: "You can't see this chat",
            message: 'Chats are open to the requester and donors who committed to the request.',
          ),
        ),
      );
    }
    if (async.isLoading && msgs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final children = <Widget>[
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'Phone numbers stay hidden unless you share them',
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ),
      ),
    ];
    if (msgs.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: TablerIcons.message_circle,
            title: 'No messages yet',
            message: 'Say hello, share where you are, or tell them when you will arrive.',
          ),
        ),
      );
    }
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final prev = i > 0 ? msgs[i - 1] : null;
      final next = i < msgs.length - 1 ? msgs[i + 1] : null;
      final mine = m.fromUid == me;
      final newDay = prev == null || !_sameDay(prev.sentAt, m.sentAt);
      final startsGroup =
          newDay ||
          prev.fromUid != m.fromUid ||
          m.sentAt.difference(prev.sentAt).inMinutes >= 5;
      final endsGroup =
          next == null ||
          next.fromUid != m.fromUid ||
          !_sameDay(next.sentAt, m.sentAt) ||
          next.sentAt.difference(m.sentAt).inMinutes >= 5;
      if (newDay) {
        children.add(
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(
                _dayLabel(m.sentAt),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
            ),
          ),
        );
      }
      children.add(
        _Bubble(
          key: ValueKey(m.id.isEmpty ? '$i' : m.id),
          m: m,
          mine: mine,
          showName: !mine && startsGroup,
          tail: endsGroup,
          topGap: startsGroup ? 10 : 2,
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.m,
    required this.mine,
    required this.showName,
    required this.tail,
    required this.topGap,
  });
  final ChatMessage m;
  final bool mine, showName, tail;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final fg = mine ? c.onFill : c.textPrimary;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(!mine && tail ? 6 : 20),
      bottomRight: Radius.circular(mine && tail ? 6 : 20),
    );
    final body = m.isLocation
        ? InkWell(
            onTap: () => _openInMaps(context, m.lat!, m.lng!),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: mine ? Colors.white24 : c.bgBrand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    TablerIcons.map_pin,
                    size: 18,
                    color: mine ? c.onFill : c.textBrand,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      Text(
                        'Open in Maps',
                        style: TextStyle(
                          fontSize: 12,
                          color: fg.withValues(alpha: .8),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Text(m.text, style: TextStyle(fontSize: 14, color: fg));

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: EdgeInsets.fromLTRB(6, topGap, 6, 2),
              child: Text(
                m.senderName.isEmpty ? 'Donor' : m.senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .78,
            ),
            margin: EdgeInsets.only(top: showName ? 0 : topGap),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: mine
                  ? (m.pending
                        ? c.fillBrand.withValues(alpha: .7)
                        : c.fillBrand)
                  : c.surface1,
              borderRadius: radius,
              border: mine ? null : Border.all(color: c.border),
            ),
            child: body,
          ),
          if (tail || m.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.pending)
                    Icon(TablerIcons.clock, size: 11, color: c.textMuted),
                  if (m.pending) const SizedBox(width: 3),
                  Text(
                    m.pending
                        ? 'Sending…'
                        : DateFormat('h:mm a').format(m.sentAt),
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Chats tab

/// Chats tab: one thread per request the user committed to or posted, newest activity first.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = [...ref.watch(chatThreadsProvider)];
    DateTime activity(BloodRequest r) =>
        ref.watch(lastMessageProvider(r.id)).value?.sentAt ??
        r.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    threads.sort((a, b) => activity(b).compareTo(activity(a)));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavClearance),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text('Chats', style: AppTheme.display(context, size: 26)),
          ),
          if (threads.isEmpty)
            const SurfaceCard(
              child: EmptyState(
                icon: TablerIcons.message_circle,
                title: 'No chats yet',
                message: 'Commit to a request, or post one, and its chat shows up here.',
              ),
            )
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < threads.length; i++)
                    ChatThreadRow(threads[i], divider: i > 0),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ChatThreadRow extends ConsumerWidget {
  const ChatThreadRow(this.r, {super.key, this.divider = false});
  final BloodRequest r;
  final bool divider;

  String _when(DateTime d) {
    final label = _dayLabel(d);
    return label == 'Today'
        ? DateFormat('h:mm a').format(d)
        : (label == 'Yesterday' ? label : DateFormat('d MMM').format(d));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final me = ref.watch(repositoryProvider).uid;
    final last = ref.watch(lastMessageProvider(r.id)).value;
    final unread = _isUnread(last, ref.watch(chatReadProvider(r.id)).value, me);
    final who = last == null
        ? ''
        : (last.fromUid == me
              ? 'You: '
              : (last.senderName.isEmpty
                    ? ''
                    : '${last.senderName.split(' ').first}: '));
    return InkWell(
      onTap: () => context.push('/chat/${r.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: c.border)) : null,
        ),
        child: Row(
          children: [
            BloodPill(
              r.bloodGroup,
              role: roleForGroup(r.bloodGroup),
              height: 24,
              size: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.title} · ${r.place}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (last != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _when(last.sentAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: unread ? c.textBrand : c.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? (r.isOpen ? 'No messages yet' : 'Closed')
                        : '$who${last.preview}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: unread ? c.textPrimary : c.textSecondary,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unread)
              Semantics(
                label: 'Unread',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.fillBrand,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              Icon(TablerIcons.chevron_right, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
