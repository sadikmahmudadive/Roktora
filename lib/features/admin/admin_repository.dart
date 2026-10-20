// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'admin_models.dart';

/// Everything the hospital dashboard reads and writes.
abstract class AdminRepository {
  /// The signed-in user's staff record, or null if they aren't hospital staff.
  Stream<AdminAccess?> access();

  Stream<HospitalProfile?> hospital(String hid);
  Future<void> saveHospital(HospitalProfile h);

  Stream<List<InventoryRow>> inventory(String hid);
  Future<void> seedInventory(String hid);
  Future<void> setStock(String hid, String group, int componentIndex, int units);

  Stream<List<BloodBatch>> batches(String hid);
  Future<void> addBatch(String hid, BloodBatch b);

  Stream<List<BloodRequest>> hospitalRequests(String hid);
  Future<void> postHospitalRequest(String hid, String hospitalName, BloodRequest r);
  Future<void> setRequestStatus(String id, String status);

  /// Names and groups for donors who committed to a request.
  Future<List<DonorEntry>> donorLookup(List<String> uids);

  Stream<List<CheckIn>> checkins(String hid);
  Future<CheckIn> startCheckIn(String hid, {required String donorName, required String group, String donorUid = '', String requestId = ''});
  Future<void> updateCheckIn(String hid, CheckIn c);

  /// Marks the donation done: logs it for the donor, rests them, and adds a unit of whole blood to stock.
  Future<void> completeDonation(String hid, CheckIn c);

  Future<List<DonorEntry>> directory();

  /// Sends an in-app message to each donor's inbox.
  Future<void> sendBulkMessage({required String hospitalName, required List<String> uids, required String title, required String body});
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository([FirebaseAuth? auth, FirebaseFirestore? db])
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _h(String hid) => _db.collection('hospitals').doc(hid);

  @override
  Stream<AdminAccess?> access() => _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value(null);
        return _db.collection('accounts').doc(u.uid).snapshots().map((s) {
          final m = s.data();
          if (m == null) return null;
          final access = AdminAccess.fromMap(u.uid, {...m, 'name': m['displayName'] ?? m['email'] ?? 'Staff'});
          final isStaff = access.role == 'admin' || access.role == 'staff';
          return isStaff && access.hospitalId.trim().isNotEmpty ? access : null;
        });
      });

  @override
  Stream<HospitalProfile?> hospital(String hid) =>
      _h(hid).snapshots().map((s) => s.exists ? HospitalProfile.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> saveHospital(HospitalProfile h) => _h(h.id).set(h.toMap(), SetOptions(merge: true));

  @override
  Stream<List<InventoryRow>> inventory(String hid) => _h(hid).collection('inventory').snapshots().map((s) {
        final rows = [for (final d in s.docs) InventoryRow.fromMap(d.id, d.data())];
        rows.sort((a, b) => bloodGroups.indexOf(a.group).compareTo(bloodGroups.indexOf(b.group)));
        return rows;
      });

  @override
  Future<void> seedInventory(String hid) async {
    final batch = _db.batch();
    for (final g in bloodGroups) {
      batch.set(_h(hid).collection('inventory').doc(g), {'target': g.contains('−') ? 12 : 40, for (final k in componentKeys) k: 0}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> setStock(String hid, String group, int componentIndex, int units) =>
      _h(hid).collection('inventory').doc(group).set({componentKeys[componentIndex]: units < 0 ? 0 : units}, SetOptions(merge: true));

  @override
  Stream<List<BloodBatch>> batches(String hid) => _h(hid)
      .collection('batches')
      .orderBy('expiresAt')
      .limit(60)
      .snapshots()
      .map((s) => [for (final d in s.docs) BloodBatch.fromMap(d.id, d.data())]);

  @override
  Future<void> addBatch(String hid, BloodBatch b) => _h(hid).collection('batches').doc(b.id).set(b.toMap());

  @override
  Stream<List<BloodRequest>> hospitalRequests(String hid) =>
      _db.collection('requests').where('hospitalId', isEqualTo: hid).snapshots().map((s) {
        final list = [for (final d in s.docs) BloodRequest.fromMap(d.id, d.data())];
        list.sort((a, b) => a.deadline.compareTo(b.deadline));
        return list;
      });

  @override
  Future<void> postHospitalRequest(String hid, String hospitalName, BloodRequest r) => _db.collection('requests').add({
        ...r.toMap(),
        'verified': true,
        'hospitalId': hid,
        'createdBy': _uid,
        'postedBy': hospitalName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> setRequestStatus(String id, String status) => _db.collection('requests').doc(id).update({
        'status': status,
        if (status == 'fulfilled') 'fulfilledAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<List<DonorEntry>> donorLookup(List<String> uids) async {
    final out = <DonorEntry>[];
    for (final uid in uids) {
      final s = await _db.collection('users').doc(uid).get();
      if (s.exists) out.add(DonorEntry.fromProfile(DonorProfile.fromMap(uid, s.data()!)));
    }
    return out;
  }

  @override
  Stream<List<CheckIn>> checkins(String hid) => _h(hid)
      .collection('checkins')
      .orderBy('at', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => [for (final d in s.docs) CheckIn.fromMap(d.id, d.data())]);

  @override
  Future<CheckIn> startCheckIn(String hid, {required String donorName, required String group, String donorUid = '', String requestId = ''}) async {
    final c = CheckIn(id: '', donorName: donorName, group: group, status: CheckInStatus.screening, at: DateTime.now(), donorUid: donorUid, requestId: requestId);
    final ref = await _h(hid).collection('checkins').add(c.toMap());
    return CheckIn(id: ref.id, donorName: donorName, group: group, status: c.status, at: c.at, donorUid: donorUid, requestId: requestId);
  }

  @override
  Future<void> updateCheckIn(String hid, CheckIn c) => _h(hid).collection('checkins').doc(c.id).set(c.toMap());

  @override
  Future<void> completeDonation(String hid, CheckIn c) async {
    final batch = _db.batch();
    batch.set(_h(hid).collection('checkins').doc(c.id), c.copyWith(status: CheckInStatus.done).toMap());
    batch.set(_h(hid).collection('inventory').doc(c.group), {'whole': FieldValue.increment(1)}, SetOptions(merge: true));
    if (c.donorUid.isNotEmpty) {
      final hospital = await _h(hid).get();
      final place = (hospital.data()?['name'] ?? 'Hospital') as String;
      final now = DateTime.now();
      batch.set(_db.collection('users').doc(c.donorUid).collection('donations').doc(), DonationRecord(date: now, place: place, note: 'Whole blood', status: 'donated').toMap());
      batch.update(_db.collection('users').doc(c.donorUid), {'donations': FieldValue.increment(1), 'lastDonation': Timestamp.fromDate(now)});
      batch.set(_db.collection('donors').doc(c.donorUid), {'donations': FieldValue.increment(1), 'available': false}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<List<DonorEntry>> directory() async {
    final snap = await _db.collection('users').limit(300).get();
    final list = [for (final d in snap.docs) DonorEntry.fromProfile(DonorProfile.fromMap(d.id, d.data()))];
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<void> sendBulkMessage({required String hospitalName, required List<String> uids, required String title, required String body}) async {
    final msg = InboxMessage(id: '', title: title, body: body, from: hospitalName, at: DateTime.now()).toMap();
    for (var i = 0; i < uids.length; i += 400) {
      final batch = _db.batch();
      for (final uid in uids.skip(i).take(400)) {
        batch.set(_db.collection('users').doc(uid).collection('inbox').doc(), msg);
      }
      await batch.commit();
    }
  }
}

/// A tiny observable value for the in-memory demo backend.
class _Live<T> {
  _Live(this.value);
  T value;
  final _c = StreamController<T>.broadcast();
  Stream<T> get stream async* {
    yield value;
    yield* _c.stream;
  }

  void set(T v) {
    value = v;
    _c.add(v);
  }
}

/// In-memory dashboard backend seeded with the design's sample data, for demo mode and tests.
class DemoAdminRepository implements AdminRepository {
  DemoAdminRepository({DemoRepository? main, bool isStaff = true}) : _main = main, _isStaff = isStaff {
    final now = DateTime.now();
    DateTime inDays(int d) => now.add(Duration(days: d));
    DateTime ago(Duration d) => now.subtract(d);

    _hospital.set(const HospitalProfile(
      id: 'mch',
      name: 'Mirpur Central Hospital',
      address: 'Section 10, Mirpur, Dhaka 1216',
      phone: '+880 2 9000 000',
      about: 'Central blood bank serving Mirpur, Pallabi and Kafrul. Open 24 hours for emergencies.',
      verified: true,
      steps: [
        VerificationStep('Documents submitted', '12 Feb 2026', true),
        VerificationStep('DGHS license verified', '20 Feb 2026', true),
        VerificationStep('Site visit by Roktora', '3 Mar 2026', true),
        VerificationStep('Annual renewal', 'Due 3 Mar 2027', false),
      ],
      docs: [
        HospitalDoc('DGHS blood bank license', 'Verified'),
        HospitalDoc('Trade license', 'Verified'),
        HospitalDoc('Fire safety certificate', 'Expires in 40 days', warning: true),
      ],
      staff: [
        StaffMember('Dr. Sultana', 'Admin · blood bank lead'),
        StaffMember('Rafi M.', 'Staff · inventory'),
        StaffMember('Emergency desk', 'Shared · post requests only'),
      ],
    ));

    const stock = {'A+': (42, 50), 'A−': (6, 12), 'B+': (51, 55), 'B−': (3, 12), 'O+': (58, 60), 'O−': (4, 15), 'AB+': (18, 20), 'AB−': (5, 8)};
    _inventory.set([
      for (final g in bloodGroups)
        () {
          final u = stock[g]!.$1;
          final a = (u * .45).round(), b = (u * .3).round(), c = (u * .18).round();
          return InventoryRow(group: g, target: stock[g]!.$2, parts: {'whole': a, 'red': b, 'plasma': c, 'platelets': u - a - b - c});
        }(),
    ]);

    _batches.set([
      BloodBatch(id: 'MCH-24-10-0412', group: 'O+', component: 'Platelets', expiresAt: inDays(1), shelfLifeDays: 5),
      BloodBatch(id: 'MCH-24-10-0398', group: 'AB+', component: 'Platelets', expiresAt: inDays(2), shelfLifeDays: 5),
      BloodBatch(id: 'MCH-24-09-0255', group: 'A+', component: 'Red cells', expiresAt: inDays(3), shelfLifeDays: 42),
      BloodBatch(id: 'MCH-24-09-0261', group: 'B+', component: 'Whole blood', expiresAt: inDays(4), shelfLifeDays: 35),
      BloodBatch(id: 'MCH-24-09-0270', group: 'O+', component: 'Whole blood', expiresAt: inDays(5), shelfLifeDays: 35),
      BloodBatch(id: 'MCH-24-09-0288', group: 'A−', component: 'Red cells', expiresAt: inDays(6), shelfLifeDays: 42),
    ]);

    BloodRequest req(String id, String g, String title, Urgency u, int need, DateTime deadline, List<String> committed, {String note = '', DateTime? created}) =>
        BloodRequest(
          id: id, bloodGroup: g, title: title, place: 'Mirpur Central Hospital', distanceKm: 0, bagsNeeded: need, committed: committed.length,
          urgency: u, deadline: deadline, verified: true, postedBy: 'Mirpur Central Hospital', note: note, committedUids: committed,
          hospitalId: 'mch', createdBy: 'staff-1', createdAt: created ?? ago(const Duration(hours: 2)),
        );
    _requests.set([
      req('h1', 'O−', '3 bags for cardiac surgery', Urgency.critical, 3, now.add(const Duration(hours: 3)), ['sk', 'fh'], note: 'Ward 4', created: ago(const Duration(hours: 2))),
      req('h2', 'B−', 'Restock for weekend surgeries', Urgency.urgent, 4, inDays(3), ['nr'], note: 'Blood bank', created: ago(const Duration(minutes: 40))),
      req('h3', 'O+', '6 bags, road accident trauma', Urgency.urgent, 6, now.add(const Duration(hours: 8)), ['ts', 'mr', 'ai', 'jh'], note: 'Emergency', created: ago(const Duration(hours: 5))),
      req('h4', 'A+', 'Thalassemia day-care', Urgency.routine, 2, inDays(4), [], note: 'Pediatrics · recurring', created: ago(const Duration(days: 1))),
    ]);

    _checkins.set([
      CheckIn(id: 'c1', donorName: 'Nusrat R.', group: 'O−', status: CheckInStatus.waiting, at: ago(const Duration(minutes: 20))),
      CheckIn(id: 'c2', donorName: 'Tania S.', group: 'O+', status: CheckInStatus.donating, at: ago(const Duration(minutes: 50)), bay: 1),
      CheckIn(id: 'c3', donorName: 'Mahmud R.', group: 'B+', status: CheckInStatus.donating, at: ago(const Duration(minutes: 35)), bay: 5),
      CheckIn(id: 'c4', donorName: 'Kamrul A.', group: 'A−', status: CheckInStatus.screening, at: ago(const Duration(minutes: 10))),
      // Past weeks so the reports have shape.
      for (var i = 0; i < 40; i++)
        CheckIn(
          id: 'old$i', donorName: 'Donor $i', group: ['O+', 'B+', 'A+', 'O+', 'AB+', 'O−', 'B−', 'A+'][i % 8],
          status: i % 11 == 0 ? CheckInStatus.deferred : CheckInStatus.done, at: ago(Duration(days: 8 + i * 5 ~/ 2)),
        ),
    ]);
  }

  final DemoRepository? _main;
  final bool _isStaff;
  final _hospital = _Live<HospitalProfile?>(null);
  final _inventory = _Live<List<InventoryRow>>(const []);
  final _batches = _Live<List<BloodBatch>>(const []);
  final _requests = _Live<List<BloodRequest>>(const []);
  final _checkins = _Live<List<CheckIn>>(const []);

  static const _people = {
    'sk': ('Sadia K.', 'O−', 'Pallabi'), 'fh': ('Farhan H.', 'O−', 'Mirpur 10'), 'nr': ('Nusrat R.', 'B−', 'Mirpur 2'),
    'ts': ('Tania S.', 'O+', 'Mirpur 1'), 'mr': ('Mahmud R.', 'B+', 'Mirpur 12'), 'ai': ('Ayesha I.', 'A+', 'Shewrapara'),
    'jh': ('Jamal H.', 'AB+', 'Pallabi'),
  };

  DonorEntry _entry(String uid) {
    final p = _people[uid]!;
    return DonorEntry(uid: uid, name: p.$1, group: p.$2, area: p.$3, donations: 3 + uid.length);
  }

  @override
  Stream<AdminAccess?> access() => Stream.value(_isStaff ? const AdminAccess(uid: 'demo-user', hospitalId: 'mch', name: 'Dr. Sultana') : null);

  @override
  Stream<HospitalProfile?> hospital(String hid) => _hospital.stream;

  @override
  Future<void> saveHospital(HospitalProfile h) async => _hospital.set(h);

  @override
  Stream<List<InventoryRow>> inventory(String hid) => _inventory.stream;

  @override
  Future<void> seedInventory(String hid) async {}

  @override
  Future<void> setStock(String hid, String group, int componentIndex, int units) async =>
      _inventory.set([for (final r in _inventory.value) r.group == group ? r.withPart(componentIndex, units) : r]);

  @override
  Stream<List<BloodBatch>> batches(String hid) => _batches.stream;

  @override
  Future<void> addBatch(String hid, BloodBatch b) async => _batches.set([..._batches.value, b]..sort((a, c) => a.expiresAt.compareTo(c.expiresAt)));

  @override
  Stream<List<BloodRequest>> hospitalRequests(String hid) => _requests.stream;

  @override
  Future<void> postHospitalRequest(String hid, String hospitalName, BloodRequest r) async {
    _requests.set([
      BloodRequest(
        id: 'h${DateTime.now().millisecondsSinceEpoch}', bloodGroup: r.bloodGroup, title: r.title, place: hospitalName, distanceKm: 0,
        bagsNeeded: r.bagsNeeded, committed: 0, urgency: r.urgency, deadline: r.deadline, verified: true, postedBy: hospitalName,
        hospitalId: hid, createdBy: 'staff-1', createdAt: DateTime.now(),
      ),
      ..._requests.value,
    ]);
  }

  @override
  Future<void> setRequestStatus(String id, String status) async => _requests.set([
        for (final r in _requests.value) r.id == id ? r.copyWith(status: status, fulfilledAt: status == 'fulfilled' ? DateTime.now() : null) : r,
      ]);

  @override
  Future<List<DonorEntry>> donorLookup(List<String> uids) async => [for (final u in uids) if (_people.containsKey(u)) _entry(u)];

  @override
  Stream<List<CheckIn>> checkins(String hid) => _checkins.stream;

  @override
  Future<CheckIn> startCheckIn(String hid, {required String donorName, required String group, String donorUid = '', String requestId = ''}) async {
    final c = CheckIn(id: 'c${DateTime.now().microsecondsSinceEpoch}', donorName: donorName, group: group, status: CheckInStatus.screening, at: DateTime.now(), donorUid: donorUid, requestId: requestId);
    _checkins.set([c, ..._checkins.value]);
    return c;
  }

  @override
  Future<void> updateCheckIn(String hid, CheckIn c) async => _checkins.set([for (final x in _checkins.value) x.id == c.id ? c : x]);

  @override
  Future<void> completeDonation(String hid, CheckIn c) async {
    await updateCheckIn(hid, c.copyWith(status: CheckInStatus.done));
    final i = _inventory.value.indexWhere((r) => r.group == c.group);
    if (i >= 0) {
      final row = _inventory.value[i];
      await setStock(hid, c.group, 0, row.part(0) + 1);
    }
    if (c.donorUid.isNotEmpty) {
      await _main?.recordDonation(DonationRecord(date: DateTime.now(), place: _hospital.value?.name ?? 'Hospital', note: 'Whole blood', status: 'donated'));
    }
  }

  @override
  Future<List<DonorEntry>> directory() async {
    final now = DateTime.now();
    DonorEntry d(String uid, String last, int n, {DateTime? lastDate, int wait = 0}) => DonorEntry(
          uid: uid, name: _people[uid]?.$1 ?? uid, group: _people[uid]?.$2 ?? 'O+', area: _people[uid]?.$3 ?? 'Mirpur',
          donations: n, lastDonation: lastDate, eligible: wait == 0, daysUntilEligible: wait,
        );
    return [
      d('fh', '14 Jun', 7, lastDate: DateTime(now.year, 6, 14)),
      d('sk', '02 Jul', 3, lastDate: DateTime(now.year, 7, 2)),
      DonorEntry(uid: 'rm', name: 'Rafiq M.', group: 'B−', area: 'Kazipara', donations: 12, lastDonation: now.subtract(const Duration(days: 78)), eligible: false, daysUntilEligible: 42),
      DonorEntry(uid: 'nb', name: 'Nadia B.', group: 'B−', area: 'Mirpur 2', donations: 4, lastDonation: DateTime(now.year, 3, 11)),
      DonorEntry(uid: 'ai', name: 'Ayesha I.', group: 'A+', area: 'Shewrapara', donations: 2, lastDonation: now.subtract(const Duration(days: 1)), eligible: false, daysUntilEligible: 119),
      d('mr', '09 May', 5, lastDate: DateTime(now.year, 5, 9)),
      DonorEntry(uid: 'ts', name: 'Tania S.', group: 'O+', area: 'Mirpur 1', donations: 9, lastDonation: now.subtract(const Duration(days: 1)), eligible: false, daysUntilEligible: 119),
      const DonorEntry(uid: 'jh', name: 'Jamal H.', group: 'AB+', area: 'Pallabi', donations: 0),
      DonorEntry(uid: 'ka', name: 'Kamrul A.', group: 'A−', area: 'Agargaon', donations: 6, lastDonation: DateTime(now.year, 1, 30)),
    ];
  }

  /// Messages sent in demo mode, for tests to inspect.
  final sentMessages = <({List<String> uids, String title, String body})>[];

  @override
  Future<void> sendBulkMessage({required String hospitalName, required List<String> uids, required String title, required String body}) async {
    sentMessages.add((uids: uids, title: title, body: body));
    if (uids.isNotEmpty) _main?.deliver(InboxMessage(id: 'm${DateTime.now().microsecondsSinceEpoch}', title: title, body: body, from: hospitalName, at: DateTime.now()));
  }
}
