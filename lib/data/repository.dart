import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

/// Backend contract. [FirebaseRepository] is the real thing; [DemoRepository]
/// keeps everything in memory so the app runs before Firebase is configured.
abstract class RoktoraRepository {
  String? get uid;
  Stream<String?> authChanges();

  /// Starts phone auth and returns an opaque verification handle.
  Future<String> sendCode(String e164Phone);
  Future<void> verifyCode(String verificationId, String code);
  Future<void> signOut();

  Stream<DonorProfile?> profile();
  Future<void> saveProfile(DonorProfile p);
  Future<void> setAvailable(bool v);

  Stream<List<BloodRequest>> requests();
  Stream<BloodRequest?> request(String id);
  Future<void> setCommitment(String requestId, bool committed);
  Future<void> postRequest(BloodRequest r);

  /// Donors near ([lat], [lng]) when known; distances are 0 for donors who haven't shared a location.
  Future<List<NearbyDonor>> nearbyDonors({double? lat, double? lng});

  /// Stores this device's push token so the backend can send alerts.
  Future<void> saveFcmToken(String token);

  /// Stores a coarse (~1 km) location for matching. Never the exact position.
  Future<void> saveApproxLocation(double lat, double lng);

  Stream<List<ChatMessage>> messages(String requestId);
  Future<void> sendMessage(String requestId, String text);

  Stream<List<DonationRecord>> donations();

  /// Logs a completed donation and bumps the profile counters.
  Future<void> recordDonation(DonationRecord d);
}

class FirebaseRepository implements RoktoraRepository {
  FirebaseRepository([FirebaseAuth? auth, FirebaseFirestore? db])
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  Stream<String?> authChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<String> sendCode(String e164Phone) {
    final c = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      verificationCompleted: (cred) async {
        // Android instant verification / auto-retrieval.
        await _auth.signInWithCredential(cred);
        if (!c.isCompleted) c.complete('auto');
      },
      verificationFailed: (e) => c.isCompleted ? null : c.completeError(e),
      codeSent: (id, _) => c.isCompleted ? null : c.complete(id),
      codeAutoRetrievalTimeout: (_) {},
    );
    return c.future;
  }

  @override
  Future<void> verifyCode(String verificationId, String code) async {
    if (verificationId == 'auto') return;
    await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  DocumentReference<Map<String, dynamic>> get _me => _db.collection('users').doc(uid);

  @override
  Stream<DonorProfile?> profile() => _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value(null);
        return _db.collection('users').doc(u.uid).snapshots().map((s) => s.exists ? DonorProfile.fromMap(u.uid, s.data()!) : null);
      });

  @override
  Future<void> saveProfile(DonorProfile p) async {
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(p.uid), p.toMap(), SetOptions(merge: true));
    batch.set(_db.collection('donors').doc(p.uid), _publicDonor(p), SetOptions(merge: true));
    await batch.commit();
  }

  /// Privacy-safe subset other signed-in users may read (no phone, no exact dates).
  Map<String, dynamic> _publicDonor(DonorProfile p) => {
        'publicName': p.publicName,
        'bloodGroup': p.bloodGroup,
        'area': p.area,
        'available': p.available && p.eligible,
        'donations': p.donations,
      };

  @override
  Future<void> setAvailable(bool v) async {
    final batch = _db.batch();
    batch.update(_me, {'available': v});
    batch.set(_db.collection('donors').doc(uid), {'available': v}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<List<BloodRequest>> requests() => _db
      .collection('requests')
      .where('deadline', isGreaterThan: Timestamp.now())
      .orderBy('deadline')
      .snapshots()
      .map((s) => s.docs.map((d) => BloodRequest.fromMap(d.id, d.data())).toList());

  @override
  Stream<BloodRequest?> request(String id) =>
      _db.collection('requests').doc(id).snapshots().map((s) => s.exists ? BloodRequest.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> setCommitment(String requestId, bool committed) => _db.collection('requests').doc(requestId).update({
        'committedUids': committed ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  @override
  Future<void> postRequest(BloodRequest r) => _db.collection('requests').add({...r.toMap(), 'createdBy': uid});

  @override
  Future<List<NearbyDonor>> nearbyDonors({double? lat, double? lng}) async {
    // Fetches available donors, then ranks by distance on the client. Swap for a geohash
    // range query if the donor pool grows beyond a few hundred.
    final snap = await _db.collection('donors').where('available', isEqualTo: true).limit(100).get();
    final out = <NearbyDonor>[];
    for (final d in snap.docs) {
      final m = d.data();
      if (d.id == uid || m['bloodGroup'] == null) continue;
      var km = 0.0;
      final dLat = (m['approxLat'] as num?)?.toDouble();
      final dLng = (m['approxLng'] as num?)?.toDouble();
      if (lat != null && lng != null && dLat != null && dLng != null) {
        km = (_haversineKm(lat, lng, dLat, dLng) * 10).round() / 10;
      }
      out.add(NearbyDonor(
        uid: d.id,
        name: (m['publicName'] ?? 'Donor') as String,
        bloodGroup: m['bloodGroup'] as String,
        distanceKm: km,
        available: (m['available'] ?? true) as bool,
        donations: (m['donations'] ?? 0) as int,
      ));
    }
    return out;
  }

  @override
  Future<void> saveFcmToken(String token) => _me.set({'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Future<void> saveApproxLocation(double lat, double lng) =>
      _db.collection('donors').doc(uid).set({'approxLat': lat, 'approxLng': lng}, SetOptions(merge: true));

  @override
  Stream<List<DonationRecord>> donations() => _auth.authStateChanges().asyncExpand((u) => u == null ? Stream.value(<DonationRecord>[]) : _donations());

  @override
  Future<void> recordDonation(DonationRecord d) async {
    final batch = _db.batch();
    batch.set(_me.collection('donations').doc(), d.toMap());
    batch.update(_me, {'donations': FieldValue.increment(1), 'lastDonation': Timestamp.fromDate(d.date), 'eligible': false});
    batch.set(_db.collection('donors').doc(uid), {'donations': FieldValue.increment(1), 'available': false}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<List<ChatMessage>> messages(String requestId) => _db
      .collection('requests/$requestId/messages')
      .orderBy('sentAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.data())).toList());

  @override
  Future<void> sendMessage(String requestId, String text) => _db
      .collection('requests/$requestId/messages')
      .add(ChatMessage(fromUid: uid!, text: text, sentAt: DateTime.now()).toMap());
}

extension FirebaseDonations on FirebaseRepository {
  Stream<List<DonationRecord>> _donations() => _db
      .collection('users/$uid/donations')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => DonationRecord.fromMap(d.data())).toList());
}

class DemoRepository implements RoktoraRepository {
  DemoRepository() {
    final now = DateTime.now();
    _requests = [
      BloodRequest(id: 'r1', bloodGroup: 'O−', title: '2 bags for cardiac surgery', place: 'Dhanmondi General', distanceKm: 1.2, bagsNeeded: 3,
          committed: 1, urgency: Urgency.critical, deadline: now.add(const Duration(hours: 3, minutes: 12)), postedBy: 'Tanvir A.',
          note: 'Ward 4, 3rd floor · Road 7A', committedUids: const ['sadia'], lat: 23.7466, lng: 90.3760),
      BloodRequest(id: 'r2', bloodGroup: 'O+', title: 'Thalassemia transfusion', place: 'Shishu Hospital', distanceKm: 2.8, bagsNeeded: 1,
          committed: 0, urgency: Urgency.urgent, deadline: now.add(const Duration(hours: 9)), verified: true, lat: 23.7737, lng: 90.3703),
      BloodRequest(id: 'r3', bloodGroup: 'Any', title: 'Weekend donation drive', place: 'Uttara Blood Bank', distanceKm: 6.0, bagsNeeded: 20,
          committed: 4, urgency: Urgency.routine, deadline: now.add(const Duration(days: 4)), verified: true,
          committedUids: const ['a', 'b', 'c', 'd'], lat: 23.8759, lng: 90.3795),
    ];
    _messages = {
      'r1': [
        ChatMessage(fromUid: 'tanvir', text: "Thank you for committing. He's in surgery prep now.", sentAt: now.subtract(const Duration(minutes: 3))),
      ],
    };
    _emit();
  }

  static const _me = 'demo-user';
  String? _uid;
  DonorProfile? _profile;
  late List<BloodRequest> _requests;
  late Map<String, List<ChatMessage>> _messages;
  final _auth = StreamController<String?>.broadcast();
  final _prof = StreamController<DonorProfile?>.broadcast();
  final _req = StreamController<List<BloodRequest>>.broadcast();
  final _msg = StreamController<void>.broadcast();

  void _emit() {
    _prof.add(_profile);
    _req.add(List.of(_requests));
    _msg.add(null);
  }

  @override
  String? get uid => _uid;

  @override
  Stream<String?> authChanges() async* {
    yield _uid;
    yield* _auth.stream;
  }

  @override
  Future<String> sendCode(String e164Phone) async => 'demo';

  @override
  Future<void> verifyCode(String verificationId, String code) async {
    if (code.length != 6) throw FirebaseAuthException(code: 'invalid-verification-code');
    _uid = _me;
    _auth.add(_uid);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _profile = null;
    _auth.add(null);
    _emit();
  }

  @override
  Stream<DonorProfile?> profile() async* {
    yield _profile;
    yield* _prof.stream;
  }

  @override
  Future<void> saveProfile(DonorProfile p) async {
    _profile = p;
    _emit();
  }

  @override
  Future<void> setAvailable(bool v) async {
    _profile = _profile?.copyWith(available: v);
    _emit();
  }

  @override
  Stream<List<BloodRequest>> requests() async* {
    yield List.of(_requests);
    yield* _req.stream;
  }

  @override
  Stream<BloodRequest?> request(String id) => requests().map((l) => l.where((r) => r.id == id).firstOrNull);

  @override
  Future<void> setCommitment(String requestId, bool committed) async {
    _requests = [
      for (final r in _requests)
        if (r.id == requestId)
          BloodRequest(
            id: r.id, bloodGroup: r.bloodGroup, title: r.title, place: r.place, distanceKm: r.distanceKm, bagsNeeded: r.bagsNeeded,
            committed: r.committedUids.where((u) => u != _me).length + (committed ? 1 : 0), urgency: r.urgency, deadline: r.deadline,
            verified: r.verified, postedBy: r.postedBy, note: r.note, lat: r.lat, lng: r.lng,
            committedUids: [...r.committedUids.where((u) => u != _me), if (committed) _me],
          )
        else
          r,
    ];
    _emit();
  }

  @override
  Future<void> postRequest(BloodRequest r) async {
    _requests = [r, ..._requests];
    _emit();
  }

  @override
  Future<void> saveFcmToken(String token) async {}

  @override
  Future<void> saveApproxLocation(double lat, double lng) async {}

  @override
  Future<List<NearbyDonor>> nearbyDonors({double? lat, double? lng}) async => const [
        NearbyDonor(uid: 'u1', name: 'Farhan H.', bloodGroup: 'O−', distanceKm: 0.6, available: true, donations: 7),
        NearbyDonor(uid: 'u2', name: 'Sadia K.', bloodGroup: 'O−', distanceKm: 0.9, available: true, donations: 3),
        NearbyDonor(uid: 'u3', name: 'Rafiq M.', bloodGroup: 'O−', distanceKm: 2.4, available: false, donations: 12),
        NearbyDonor(uid: 'u4', name: 'Ayesha I.', bloodGroup: 'A+', distanceKm: 0.8, available: true, donations: 2),
        NearbyDonor(uid: 'u5', name: 'Mahmud R.', bloodGroup: 'B+', distanceKm: 1.5, available: true, donations: 5),
        NearbyDonor(uid: 'u6', name: 'Tania S.', bloodGroup: 'O+', distanceKm: 2.8, available: true, donations: 9),
        NearbyDonor(uid: 'u7', name: 'Jamal H.', bloodGroup: 'AB+', distanceKm: 4.2, available: false, donations: 1),
        NearbyDonor(uid: 'u8', name: 'Nadia B.', bloodGroup: 'B−', distanceKm: 4.6, available: true, donations: 4),
      ];

  final List<DonationRecord> _history = [
    DonationRecord(date: DateTime(2026, 6, 14), place: 'Dhanmondi General', note: 'Whole blood · cardiac surgery', status: 'used'),
    DonationRecord(date: DateTime(2026, 2, 2), place: 'Uttara Blood Bank', note: 'Donation drive', status: 'used'),
  ];
  final _hist = StreamController<void>.broadcast();

  @override
  Stream<List<DonationRecord>> donations() async* {
    yield List.of(_history);
    yield* _hist.stream.map((_) => List.of(_history));
  }

  @override
  Future<void> recordDonation(DonationRecord d) async {
    _history.insert(0, d);
    _profile = _profile?.copyWith(donations: (_profile?.donations ?? 0) + 1, lastDonation: d.date, eligible: false);
    _hist.add(null);
    _emit();
  }

  @override
  Stream<List<ChatMessage>> messages(String requestId) async* {
    yield List.of(_messages[requestId] ?? const []);
    yield* _msg.stream.map((_) => List.of(_messages[requestId] ?? const []));
  }

  @override
  Future<void> sendMessage(String requestId, String text) async {
    _messages.putIfAbsent(requestId, () => []).add(ChatMessage(fromUid: _me, text: text, sentAt: DateTime.now()));
    _emit();
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a));
}
