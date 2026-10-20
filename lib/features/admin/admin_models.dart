import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models.dart';

const bloodComponents = ['Whole blood', 'Red cells', 'Plasma', 'Platelets'];

/// Firestore keys for [bloodComponents], in the same order.
const componentKeys = ['whole', 'red', 'plasma', 'platelets'];

/// A signed-in user's staff record: which hospital they manage and their role.
class AdminAccess {
  const AdminAccess({required this.uid, required this.hospitalId, required this.name, this.role = 'admin'});
  final String uid, hospitalId, name, role;
  bool get isAdmin => role == 'admin';

  factory AdminAccess.fromMap(String uid, Map<String, dynamic> m) => AdminAccess(
        uid: uid,
        hospitalId: (m['hospitalId'] ?? '') as String,
        name: (m['name'] ?? 'Staff') as String,
        role: (m['role'] ?? 'staff') as String,
      );
}

class VerificationStep {
  const VerificationStep(this.label, this.when, this.done);
  final String label, when;
  final bool done;
  Map<String, dynamic> toMap() => {'label': label, 'when': when, 'done': done};
  factory VerificationStep.fromMap(Map<String, dynamic> m) =>
      VerificationStep((m['label'] ?? '') as String, (m['when'] ?? '') as String, (m['done'] ?? false) as bool);
}

class HospitalDoc {
  const HospitalDoc(this.name, this.status, {this.warning = false});
  final String name, status;
  final bool warning;
  Map<String, dynamic> toMap() => {'name': name, 'status': status, 'warning': warning};
  factory HospitalDoc.fromMap(Map<String, dynamic> m) =>
      HospitalDoc((m['name'] ?? '') as String, (m['status'] ?? '') as String, warning: (m['warning'] ?? false) as bool);
}

class StaffMember {
  const StaffMember(this.name, this.role, {this.twoFa = true});
  final String name, role;
  final bool twoFa;
  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return (p.length == 1 ? p.first.substring(0, p.first.length.clamp(0, 2)) : '${p.first[0]}${p.last[0]}').toUpperCase();
  }

  Map<String, dynamic> toMap() => {'name': name, 'role': role, 'twoFa': twoFa};
  factory StaffMember.fromMap(Map<String, dynamic> m) =>
      StaffMember((m['name'] ?? '') as String, (m['role'] ?? '') as String, twoFa: (m['twoFa'] ?? true) as bool);
}

class HospitalProfile {
  const HospitalProfile({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.about = '',
    this.verified = false,
    this.steps = const [],
    this.docs = const [],
    this.staff = const [],
  });
  final String id, name, address, phone, about;
  final bool verified;
  final List<VerificationStep> steps;
  final List<HospitalDoc> docs;
  final List<StaffMember> staff;

  Map<String, dynamic> toMap() => {
        'name': name, 'address': address, 'phone': phone, 'about': about, 'verified': verified,
        'steps': [for (final s in steps) s.toMap()],
        'docs': [for (final d in docs) d.toMap()],
        'staff': [for (final s in staff) s.toMap()],
      };

  factory HospitalProfile.fromMap(String id, Map<String, dynamic> m) => HospitalProfile(
        id: id,
        name: (m['name'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        about: (m['about'] ?? '') as String,
        verified: (m['verified'] ?? false) as bool,
        steps: [for (final s in (m['steps'] as List? ?? const [])) VerificationStep.fromMap(Map<String, dynamic>.from(s as Map))],
        docs: [for (final d in (m['docs'] as List? ?? const [])) HospitalDoc.fromMap(Map<String, dynamic>.from(d as Map))],
        staff: [for (final s in (m['staff'] as List? ?? const [])) StaffMember.fromMap(Map<String, dynamic>.from(s as Map))],
      );
}

enum StockLevel { shortage, low, healthy }

/// Stock for one blood group, split by component.
class InventoryRow {
  const InventoryRow({required this.group, required this.target, required this.parts});
  final String group;
  final int target;

  /// Units per component, keyed by [componentKeys].
  final Map<String, int> parts;

  int part(int componentIndex) => parts[componentKeys[componentIndex]] ?? 0;
  int get units => parts.values.fold(0, (a, b) => a + b);
  double get ratio => target == 0 ? 1 : units / target;

  /// Under 40% of target is a shortage, under 75% is low.
  StockLevel get level => ratio < .4 ? StockLevel.shortage : (ratio < .75 ? StockLevel.low : StockLevel.healthy);

  /// Rh-negative groups are rarer, so a shortage there is shown as danger and elsewhere as a warning.
  bool get isNegative => group.endsWith('−') || group.endsWith('-');

  InventoryRow withPart(int componentIndex, int units) =>
      InventoryRow(group: group, target: target, parts: {...parts, componentKeys[componentIndex]: units < 0 ? 0 : units});

  Map<String, dynamic> toMap() => {'target': target, ...parts};
  factory InventoryRow.fromMap(String group, Map<String, dynamic> m) => InventoryRow(
        group: group,
        target: (m['target'] ?? 0) as int,
        parts: {for (final k in componentKeys) k: (m[k] ?? 0) as int},
      );
}

class BloodBatch {
  const BloodBatch({required this.id, required this.group, required this.component, required this.expiresAt, this.shelfLifeDays = 35});
  final String id, group, component;
  final DateTime expiresAt;
  final int shelfLifeDays;

  int get daysLeft {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? 0 : (d.inHours / 24).ceil();
  }

  Map<String, dynamic> toMap() => {'group': group, 'component': component, 'expiresAt': Timestamp.fromDate(expiresAt), 'shelfLifeDays': shelfLifeDays};
  factory BloodBatch.fromMap(String id, Map<String, dynamic> m) => BloodBatch(
        id: id,
        group: (m['group'] ?? '') as String,
        component: (m['component'] ?? '') as String,
        expiresAt: ((m['expiresAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
        shelfLifeDays: (m['shelfLifeDays'] ?? 35) as int,
      );
}

enum CheckInStatus { waiting, screening, donating, done, deferred }

class CheckIn {
  const CheckIn({
    required this.id,
    required this.donorName,
    required this.group,
    required this.status,
    required this.at,
    this.donorUid = '',
    this.bay,
    this.requestId = '',
  });
  final String id, donorName, group, donorUid, requestId;
  final CheckInStatus status;
  final int? bay;
  final DateTime at;

  CheckIn copyWith({CheckInStatus? status, int? bay}) => CheckIn(
        id: id, donorName: donorName, group: group, status: status ?? this.status, at: at,
        donorUid: donorUid, bay: bay ?? this.bay, requestId: requestId,
      );

  Map<String, dynamic> toMap() => {
        'donorName': donorName, 'group': group, 'status': status.name, 'at': Timestamp.fromDate(at),
        'donorUid': donorUid, 'requestId': requestId, if (bay != null) 'bay': bay,
      };

  factory CheckIn.fromMap(String id, Map<String, dynamic> m) => CheckIn(
        id: id,
        donorName: (m['donorName'] ?? '') as String,
        group: (m['group'] ?? '') as String,
        status: CheckInStatus.values.byName((m['status'] ?? 'waiting') as String),
        at: ((m['at'] as Timestamp?) ?? Timestamp.now()).toDate(),
        donorUid: (m['donorUid'] ?? '') as String,
        bay: m['bay'] as int?,
        requestId: (m['requestId'] ?? '') as String,
      );
}

/// A registered donor as the hospital sees them: first name + initial only.
class DonorEntry {
  const DonorEntry({required this.uid, required this.name, required this.group, required this.area, required this.donations, this.lastDonation, this.eligible = true, this.daysUntilEligible = 0});
  final String uid, name, group, area;
  final int donations;
  final DateTime? lastDonation;
  final bool eligible;
  final int daysUntilEligible;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return (p.length == 1 ? p.first.substring(0, p.first.length.clamp(0, 2)) : '${p.first[0]}${p.last[0]}').toUpperCase();
  }

  factory DonorEntry.fromProfile(DonorProfile p) => DonorEntry(
        uid: p.uid,
        name: p.publicName,
        group: p.bloodGroup ?? '?',
        area: p.area,
        donations: p.donations,
        lastDonation: p.lastDonation,
        eligible: p.isEligibleNow,
        daysUntilEligible: p.daysUntilEligible,
      );
}

/// A message a hospital sent to a donor.
class InboxMessage {
  const InboxMessage({required this.id, required this.title, required this.body, required this.from, required this.at, this.read = false});
  final String id, title, body, from;
  final DateTime at;
  final bool read;

  Map<String, dynamic> toMap() => {'title': title, 'body': body, 'from': from, 'at': Timestamp.fromDate(at), 'read': read};
  factory InboxMessage.fromMap(String id, Map<String, dynamic> m) => InboxMessage(
        id: id,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        from: (m['from'] ?? '') as String,
        at: ((m['at'] as Timestamp?) ?? Timestamp.now()).toDate(),
        read: (m['read'] ?? false) as bool,
      );
}

// ------------------------------------------------------------------ reports

enum ReportPeriod { weekly, monthly }

class ReportKpi {
  const ReportKpi(this.label, this.value, {this.positive});
  final String label, value;

  /// null = neutral.
  final bool? positive;
}

class ReportData {
  const ReportData({required this.labels, required this.values, required this.kpis, required this.byGroup, required this.rangeLabel});
  final List<String> labels;
  final List<int> values;
  final List<ReportKpi> kpis;

  /// Units collected per blood group, most first.
  final List<(String, int)> byGroup;
  final String rangeLabel;
  int get max => values.fold(1, (a, b) => a > b ? a : b);
  int get total => values.fold(0, (a, b) => a + b);
}

/// Aggregates check-ins and requests into the Reports screen. Aggregate only, never per donor.
ReportData buildReport({
  required List<CheckIn> checkins,
  required List<BloodRequest> requests,
  required ReportPeriod period,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final weekly = period == ReportPeriod.weekly;
  final n = 12;

  // Bucket i = 0 is the oldest. Weekly buckets are 7-day windows ending today; monthly are calendar months.
  DateTime start(int i) => weekly
      ? DateTime(today.year, today.month, today.day).subtract(Duration(days: 7 * (n - i)))
      : DateTime(today.year, today.month - (n - 1 - i), 1);
  DateTime end(int i) => i == n - 1 ? today.add(const Duration(days: 1)) : start(i + 1);

  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final labels = [for (var i = 0; i < n; i++) weekly ? 'W${_isoWeek(start(i))}' : months[start(i).month - 1]];

  final done = checkins.where((c) => c.status == CheckInStatus.done).toList();
  final values = [
    for (var i = 0; i < n; i++) done.where((c) => !c.at.isBefore(start(i)) && c.at.isBefore(end(i))).length,
  ];

  final inRange = done.where((c) => !c.at.isBefore(start(0))).toList();
  final groups = <String, int>{};
  for (final c in inRange) {
    groups[c.group] = (groups[c.group] ?? 0) + 1;
  }
  final byGroup = groups.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));

  // Fulfilment and speed come from requests the hospital closed in the window.
  final closed = requests.where((r) => !r.isOpen && r.status != 'open').toList();
  final fulfilled = closed.where((r) => r.status == 'fulfilled').toList();
  final fulfilmentPct = closed.isEmpty ? null : (fulfilled.length * 100 / closed.length).round();
  final times = [
    for (final r in fulfilled)
      if (r.createdAt != null && r.fulfilledAt != null) r.fulfilledAt!.difference(r.createdAt!),
  ]..sort();
  final median = times.isEmpty ? null : times[times.length ~/ 2];

  final screened = checkins.where((c) => c.status == CheckInStatus.done || c.status == CheckInStatus.deferred).length;
  final deferred = checkins.where((c) => c.status == CheckInStatus.deferred).length;
  final deferralPct = screened == 0 ? null : (deferred * 100 / screened).round();

  String dur(Duration d) => d.inHours > 0 ? '${d.inHours} h ${d.inMinutes % 60} m' : '${d.inMinutes} m';

  final last = values.last, prev = values.length > 1 ? values[values.length - 2] : 0;
  String? delta;
  if (prev > 0) {
    final pct = ((last - prev) * 100 / prev).round();
    delta = '${pct >= 0 ? '+' : '−'}${pct.abs()}% vs ${weekly ? 'last week' : 'last month'}';
  }

  return ReportData(
    labels: labels,
    values: values,
    byGroup: byGroup,
    rangeLabel: weekly ? 'Last 12 weeks' : 'Last 12 months',
    kpis: [
      ReportKpi('Units collected', '$last${delta == null ? '' : ' · $delta'}', positive: prev == 0 ? null : last >= prev),
      ReportKpi('Requests fulfilled', fulfilmentPct == null ? '—' : '$fulfilmentPct%', positive: fulfilmentPct == null ? null : fulfilmentPct >= 80),
      ReportKpi('Median time to fill', median == null ? '—' : dur(median)),
      ReportKpi('Deferral rate', deferralPct == null ? '—' : '$deferralPct%', positive: deferralPct == null ? null : deferralPct <= 10),
    ],
  );
}

int _isoWeek(DateTime d) {
  final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  return ((dayOfYear - d.weekday + 10) / 7).floor().clamp(1, 53);
}
