import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/admin/admin_models.dart' show InboxMessage;
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

  /// Email + password sign-in (alongside phone and Google).
  Future<void> signInWithEmail(String email, String password);
  Future<void> createAccountWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);

  /// Google sign-in through Firebase's OAuth flow (no extra native SDK).
  Future<void> signInWithGoogle();

  Stream<DonorProfile?> profile();
  Future<void> saveProfile(DonorProfile p);
  Future<void> setAvailable(bool v);

  Stream<List<BloodRequest>> requests();
  Stream<BloodRequest?> request(String id);
  Future<void> setCommitment(String requestId, bool committed);
  Future<void> postRequest(BloodRequest r);

  /// Requests the signed-in user posted, newest first (any status).
  Stream<List<BloodRequest>> myRequests();

  /// Poster-only: mark a request 'fulfilled' or 'closed' (or reopen with 'open').
  Future<void> setRequestStatus(String id, String status);

  /// Flags a request for the moderation team.
  Future<void> reportRequest(String requestId, String reason);

  /// Messages hospitals sent to this donor, newest first.
  Stream<List<InboxMessage>> inbox();
  Future<void> markInboxRead(String id);

  /// Removes the profile, donation history and sign-in. Throws `requires-recent-login` if the
  /// sign-in is too old.
  Future<void> deleteAccount();

  /// Donors near ([lat], [lng]) when known; distances are 0 for donors who haven't shared a location.
  Future<List<NearbyDonor>> nearbyDonors({double? lat, double? lng});

  /// Stores this device's push token so the backend can send alerts.
  Future<void> saveFcmToken(String token);

  /// Stores a coarse (~1 km) location for matching. Never the exact position.
  Future<void> saveApproxLocation(double lat, double lng);

  Stream<List<ChatMessage>> messages(String requestId);
  Future<void> sendMessage(String requestId, String text);

  /// Shares a map position into the chat (text holds the place name).
  Future<void> sendLocation(String requestId, double lat, double lng, String label);

  /// Latest message of a thread, for the Chats list.
  Stream<ChatMessage?> lastMessage(String requestId);

  /// When this user last opened the thread (null if never); unread = newer messages from others.
  Stream<DateTime?> chatReadAt(String requestId);
  Future<void> markChatRead(String requestId);

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
  String? _chatName;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  Stream<String?> authChanges() => _auth.authStateChanges().asyncMap((u) async {
        if (u != null) await _recordAccount(u);
        return u?.uid;
      });

  /// Stores/refreshes accounts/{uid}. New accounts get role "user"; only the console can change
  /// `role` / `hospitalId` (the rules reject client writes to them). Never blocks sign-in.
  Future<void> _recordAccount(User u) async {
    try {
      final ref = _db.collection('accounts').doc(u.uid);
      final info = <String, dynamic>{
        'email': u.email,
        'phone': u.phoneNumber,
        'displayName': u.displayName,
        'photoURL': u.photoURL,
        'providers': [for (final p in u.providerData) p.providerId],
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      final snap = await ref.get();
      if (snap.exists) {
        await ref.update(info);
      } else {
        await ref.set({...info, 'role': 'user', 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

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

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> createAccountWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {
      // Verification mail is a courtesy; the account exists either way.
    }
  }

  @override
  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signInWithGoogle() async {
    await _auth.signInWithProvider(GoogleAuthProvider()..addScope('email'));
  }

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
        'available': p.available && p.isEligibleNow,
        'donations': p.donations,
      };

  @override
  Future<void> setAvailable(bool v) async {
    final snap = await _me.get();
    final eligible = snap.exists ? DonorProfile.fromMap(uid!, snap.data()!).isEligibleNow : true;
    final batch = _db.batch();
    batch.update(_me, {'available': v});
    batch.set(_db.collection('donors').doc(uid), {'available': v && eligible}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<List<BloodRequest>> requests() => _db
      .collection('requests')
      .where('deadline', isGreaterThan: Timestamp.now())
      .orderBy('deadline')
      .snapshots()
      .map((s) => s.docs.map((d) => BloodRequest.fromMap(d.id, d.data())).where((r) => r.isOpen).toList());

  @override
  Stream<BloodRequest?> request(String id) =>
      _db.collection('requests').doc(id).snapshots().map((s) => s.exists ? BloodRequest.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> setCommitment(String requestId, bool committed) => _db.collection('requests').doc(requestId).update({
        'committedUids': committed ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  @override
  Future<void> postRequest(BloodRequest r) => _db.collection('requests').add({...r.toMap(), 'createdBy': uid, 'createdAt': FieldValue.serverTimestamp()});

  @override
  Stream<List<BloodRequest>> myRequests() => _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value(<BloodRequest>[]);
        return _db.collection('requests').where('createdBy', isEqualTo: u.uid).snapshots().map((s) {
          final list = s.docs.map((d) => BloodRequest.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.deadline.compareTo(a.deadline));
          return list;
        });
      });

  @override
  Future<void> setRequestStatus(String id, String status) => _db.collection('requests').doc(id).update({
        'status': status,
        if (status == 'fulfilled') 'fulfilledAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> reportRequest(String requestId, String reason) => _db.collection('reports').add({
        'requestId': requestId,
        'reason': reason,
        'reportedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<InboxMessage>> inbox() => _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value(<InboxMessage>[]);
        return _db
            .collection('users/${u.uid}/inbox')
            .orderBy('at', descending: true)
            .limit(50)
            .snapshots()
            .map((s) => [for (final d in s.docs) InboxMessage.fromMap(d.id, d.data())]);
      });

  @override
  Future<void> markInboxRead(String id) => _me.collection('inbox').doc(id).update({'read': true});

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Deleting the sign-in needs a recent login; check first so we never leave a half-deleted account.
    final last = user.metadata.lastSignInTime;
    if (last == null || DateTime.now().difference(last).inMinutes > 5) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final donations = await _db.collection('users/${user.uid}/donations').get();
    final batch = _db.batch();
    for (final d in donations.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('donors').doc(user.uid));
    batch.delete(_db.collection('users').doc(user.uid));
    await batch.commit();
    await user.delete();
  }

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
    batch.update(_me, {'donations': FieldValue.increment(1), 'lastDonation': Timestamp.fromDate(d.date)});
    batch.set(_db.collection('donors').doc(uid), {'donations': FieldValue.increment(1), 'available': false}, SetOptions(merge: true)); // resting until the cooldown ends
    await batch.commit();
  }

  @override
  Stream<List<ChatMessage>> messages(String requestId) => _db
      .collection('requests/$requestId/messages')
      .orderBy('sentAt')
      .snapshots(includeMetadataChanges: true)
      .map((s) => [for (final d in s.docs) ChatMessage.fromMap(d.data(), id: d.id, pending: d.metadata.hasPendingWrites)]);

  /// How this user appears in chats: the donor's public "First L." name, cached after the first lookup.
  Future<String> _senderName() async {
    if (_chatName != null) return _chatName!;
    try {
      final s = await _me.get();
      if (s.exists) _chatName = DonorProfile.fromMap(uid!, s.data()!).publicName;
    } catch (_) {}
    final fallback = _auth.currentUser?.displayName;
    return _chatName ?? ((fallback != null && fallback.trim().isNotEmpty) ? fallback.trim() : 'Donor');
  }

  Future<void> _post(String requestId, Map<String, dynamic> body) async {
    // Written with the server timestamp so ordering doesn't depend on phone clocks (the rules require it).
    await _db.collection('requests/$requestId/messages').add({
      'fromUid': uid,
      'senderName': await _senderName(),
      'sentAt': FieldValue.serverTimestamp(),
      ...body,
    });
  }

  @override
  Future<void> sendMessage(String requestId, String text) => _post(requestId, {'text': text});

  @override
  Future<void> sendLocation(String requestId, double lat, double lng, String label) =>
      _post(requestId, {'kind': 'location', 'lat': lat, 'lng': lng, 'text': label.isEmpty ? 'Shared location' : label});

  @override
  Stream<ChatMessage?> lastMessage(String requestId) => _db
      .collection('requests/$requestId/messages')
      .orderBy('sentAt', descending: true)
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.isEmpty ? null : ChatMessage.fromMap(s.docs.first.data(), id: s.docs.first.id, pending: s.docs.first.metadata.hasPendingWrites));

  @override
  Stream<DateTime?> chatReadAt(String requestId) => _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value(null);
        return _db.doc('users/${u.uid}/chatReads/$requestId').snapshots().map((s) => (s.data()?['readAt'] as Timestamp?)?.toDate());
      });

  @override
  Future<void> markChatRead(String requestId) =>
      _db.doc('users/$uid/chatReads/$requestId').set({'readAt': FieldValue.serverTimestamp()});
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
        ChatMessage(fromUid: 'tanvir', senderName: 'Tanvir A.', text: "Thank you for committing. He's in surgery prep now.", sentAt: now.subtract(const Duration(minutes: 3))),
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
  Future<void> signInWithEmail(String email, String password) async {
    if (password.length < 6) throw FirebaseAuthException(code: 'wrong-password');
    _uid = _me;
    _auth.add(_uid);
  }

  @override
  Future<void> createAccountWithEmail(String email, String password) async {
    if (password.length < 6) throw FirebaseAuthException(code: 'weak-password');
    _uid = _me;
    _auth.add(_uid);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signInWithGoogle() async {
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
    yield _requests.where((r) => r.isOpen).toList();
    yield* _req.stream.map((l) => l.where((r) => r.isOpen).toList());
  }

  @override
  Stream<BloodRequest?> request(String id) async* {
    yield _requests.where((r) => r.id == id).firstOrNull;
    yield* _req.stream.map((_) => _requests.where((r) => r.id == id).firstOrNull);
  }

  @override
  Future<void> setCommitment(String requestId, bool committed) async {
    _requests = [
      for (final r in _requests)
        if (r.id == requestId)
          BloodRequest(
            id: r.id, bloodGroup: r.bloodGroup, title: r.title, place: r.place, distanceKm: r.distanceKm, bagsNeeded: r.bagsNeeded,
            committed: r.committedUids.where((u) => u != _me).length + (committed ? 1 : 0), urgency: r.urgency, deadline: r.deadline,
            verified: r.verified, postedBy: r.postedBy, note: r.note, lat: r.lat, lng: r.lng, createdBy: r.createdBy, status: r.status, hospitalId: r.hospitalId, createdAt: r.createdAt, fulfilledAt: r.fulfilledAt,
            committedUids: [...r.committedUids.where((u) => u != _me), if (committed) _me],
          )
        else
          r,
    ];
    _emit();
  }

  @override
  Future<void> postRequest(BloodRequest r) async {
    _requests = [
      BloodRequest(
        id: 'r${DateTime.now().millisecondsSinceEpoch}', bloodGroup: r.bloodGroup, title: r.title, place: r.place, distanceKm: r.distanceKm,
        bagsNeeded: r.bagsNeeded, committed: 0, urgency: r.urgency, deadline: r.deadline, postedBy: r.postedBy, lat: r.lat, lng: r.lng,
        createdBy: _me,
      ),
      ..._requests,
    ];
    _emit();
  }

  @override
  Stream<List<BloodRequest>> myRequests() async* {
    yield _requests.where((r) => r.isMine(_uid)).toList();
    yield* _req.stream.map((_) => _requests.where((r) => r.isMine(_uid)).toList());
  }

  @override
  Future<void> setRequestStatus(String id, String status) async {
    _requests = [for (final r in _requests) r.id == id ? r.copyWith(status: status, fulfilledAt: status == 'fulfilled' ? DateTime.now() : null) : r];
    _emit();
  }

  @override
  Future<void> reportRequest(String requestId, String reason) async {}

  final List<InboxMessage> _inbox = [];
  final _inboxStream = StreamController<void>.broadcast();

  /// Lets the demo hospital dashboard drop a message in the donor's inbox.
  void deliver(InboxMessage m) {
    _inbox.insert(0, m);
    _inboxStream.add(null);
  }

  @override
  Stream<List<InboxMessage>> inbox() async* {
    yield List.of(_inbox);
    yield* _inboxStream.stream.map((_) => List.of(_inbox));
  }

  @override
  Future<void> markInboxRead(String id) async {
    final i = _inbox.indexWhere((m) => m.id == id);
    if (i >= 0) {
      final m = _inbox[i];
      _inbox[i] = InboxMessage(id: m.id, title: m.title, body: m.body, from: m.from, at: m.at, read: true);
      _inboxStream.add(null);
    }
  }

  @override
  Future<void> deleteAccount() async => signOut();

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
    _profile = _profile?.copyWith(donations: (_profile?.donations ?? 0) + 1, lastDonation: d.date);
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
    _messages.putIfAbsent(requestId, () => []).add(ChatMessage(fromUid: _me, text: text, sentAt: DateTime.now(), senderName: _profile?.publicName ?? 'You'));
    _emit();
  }

  @override
  Future<void> sendLocation(String requestId, double lat, double lng, String label) async {
    _messages.putIfAbsent(requestId, () => []).add(ChatMessage(fromUid: _me, text: label, sentAt: DateTime.now(), senderName: _profile?.publicName ?? 'You', lat: lat, lng: lng));
    _emit();
  }

  @override
  Stream<ChatMessage?> lastMessage(String requestId) async* {
    ChatMessage? last() => (_messages[requestId]?.isNotEmpty ?? false) ? _messages[requestId]!.last : null;
    yield last();
    yield* _msg.stream.map((_) => last());
  }

  final _reads = <String, DateTime>{};

  @override
  Stream<DateTime?> chatReadAt(String requestId) async* {
    yield _reads[requestId];
    yield* _msg.stream.map((_) => _reads[requestId]);
  }

  @override
  Future<void> markChatRead(String requestId) async {
    _reads[requestId] = DateTime.now();
    _msg.add(null);
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a));
}
