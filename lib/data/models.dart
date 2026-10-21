import 'package:cloud_firestore/cloud_firestore.dart';

/// Areas offered at sign-up and in the profile editor.
const donorAreas = ['Dhanmondi, Dhaka', 'Mirpur, Dhaka', 'Uttara, Dhaka', 'Agrabad, Chattogram'];

const bloodGroups = ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−'];

enum Urgency { critical, urgent, routine }

class DonorProfile {
  const DonorProfile({
    required this.uid,
    required this.name,
    required this.area,
    this.bloodGroup,
    this.available = true,
    this.donations = 0,
    this.lastDonation,
    this.eligible = true,
    this.lat,
    this.lng,
  });

  final String uid, name, area;

  /// Where the donor set their location on the map (null for profiles made before maps).
  final double? lat, lng;
  bool get hasLocation => lat != null && lng != null;
  final String? bloodGroup;
  final bool available, eligible;
  final int donations;
  final DateTime? lastDonation;

  /// Whole-blood donors rest this long between donations.
  static const cooldownDays = 120;

  DateTime? get nextEligibleDate => lastDonation?.add(const Duration(days: cooldownDays));

  /// Days left before the next donation is allowed; 0 once the cooldown is over.
  int get daysUntilEligible {
    final next = nextEligibleDate;
    if (next == null || !next.isAfter(DateTime.now())) return 0;
    return (next.difference(DateTime.now()).inHours / 24).ceil();
  }

  /// Screening passed AND the cooldown since the last donation has finished.
  bool get isEligibleNow => eligible && daysUntilEligible == 0;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return p.length == 1 ? p.first.substring(0, p.first.length.clamp(0, 2)).toUpperCase() : '${p.first[0]}${p.last[0]}'.toUpperCase();
  }

  /// Privacy-first display name, e.g. "Nusrat R."
  String get publicName {
    final p = name.trim().split(RegExp(r'\s+'));
    return p.length == 1 ? p.first : '${p.first} ${p.last[0]}.';
  }

  DonorProfile copyWith({String? name, String? area, String? bloodGroup, bool? available, bool? eligible, int? donations, DateTime? lastDonation, double? lat, double? lng}) =>
      DonorProfile(
        uid: uid, name: name ?? this.name, area: area ?? this.area, bloodGroup: bloodGroup ?? this.bloodGroup,
        available: available ?? this.available, eligible: eligible ?? this.eligible,
        donations: donations ?? this.donations, lastDonation: lastDonation ?? this.lastDonation,
        lat: lat ?? this.lat, lng: lng ?? this.lng,
      );

  Map<String, dynamic> toMap() => {
        'name': name, 'area': area, 'bloodGroup': bloodGroup, 'available': available, 'eligible': eligible,
        'donations': donations, 'lastDonation': lastDonation == null ? null : Timestamp.fromDate(lastDonation!),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  factory DonorProfile.fromMap(String uid, Map<String, dynamic> m) => DonorProfile(
        uid: uid,
        name: (m['name'] ?? '') as String,
        area: (m['area'] ?? '') as String,
        bloodGroup: m['bloodGroup'] as String?,
        available: (m['available'] ?? true) as bool,
        eligible: (m['eligible'] ?? true) as bool,
        donations: (m['donations'] ?? 0) as int,
        lastDonation: (m['lastDonation'] as Timestamp?)?.toDate(),
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

class BloodRequest {
  const BloodRequest({
    required this.id,
    required this.bloodGroup,
    required this.title,
    required this.place,
    required this.distanceKm,
    required this.bagsNeeded,
    required this.committed,
    required this.urgency,
    required this.deadline,
    this.verified = false,
    this.postedBy = '',
    this.note = '',
    this.committedUids = const [],
    this.lat,
    this.lng,
    this.createdBy = '',
    this.status = 'open',
    this.hospitalId = '',
    this.createdAt,
    this.fulfilledAt,
  });

  final String id, bloodGroup, title, place, postedBy, note;

  /// Set for requests posted from a hospital dashboard (empty for individual requests).
  final String hospitalId;

  /// When the request was posted / marked fulfilled. Used for time-to-fill reporting.
  final DateTime? createdAt, fulfilledAt;

  /// Uid of the poster (empty for hospital-posted or older requests).
  final String createdBy;

  /// open | fulfilled | closed
  final String status;
  bool get isOpen => status == 'open';
  bool isMine(String? uid) => uid != null && createdBy == uid;

  BloodRequest copyWith({String? status, DateTime? fulfilledAt}) => BloodRequest(
        id: id, bloodGroup: bloodGroup, title: title, place: place, distanceKm: distanceKm, bagsNeeded: bagsNeeded,
        committed: committed, urgency: urgency, deadline: deadline, verified: verified, postedBy: postedBy, note: note,
        committedUids: committedUids, lat: lat, lng: lng, createdBy: createdBy, status: status ?? this.status,
        hospitalId: hospitalId, createdAt: createdAt, fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      );

  /// Where blood is needed (hospital or ward). Null for older requests, which then don't appear on the map.
  final double? lat, lng;
  bool get hasLocation => lat != null && lng != null;
  final double distanceKm;
  final int bagsNeeded, committed;
  final Urgency urgency;
  final DateTime deadline;
  final bool verified;
  final List<String> committedUids;

  double get progress => bagsNeeded == 0 ? 0 : committed / bagsNeeded;

  Map<String, dynamic> toMap() => {
        'bloodGroup': bloodGroup, 'title': title, 'place': place, 'distanceKm': distanceKm,
        'bagsNeeded': bagsNeeded, 'urgency': urgency.name, 'deadline': Timestamp.fromDate(deadline),
        'verified': verified, 'postedBy': postedBy, 'note': note, 'committedUids': committedUids,
        'status': status,
        if (hospitalId.isNotEmpty) 'hospitalId': hospitalId,
        if (fulfilledAt != null) 'fulfilledAt': Timestamp.fromDate(fulfilledAt!),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  factory BloodRequest.fromMap(String id, Map<String, dynamic> m) {
    final uids = List<String>.from(m['committedUids'] ?? const []);
    return BloodRequest(
      id: id,
      bloodGroup: (m['bloodGroup'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      place: (m['place'] ?? '') as String,
      distanceKm: ((m['distanceKm'] ?? 0) as num).toDouble(),
      bagsNeeded: (m['bagsNeeded'] ?? 1) as int,
      committed: uids.length,
      urgency: Urgency.values.byName((m['urgency'] ?? 'routine') as String),
      deadline: ((m['deadline'] as Timestamp?) ?? Timestamp.now()).toDate(),
      verified: (m['verified'] ?? false) as bool,
      postedBy: (m['postedBy'] ?? '') as String,
      note: (m['note'] ?? '') as String,
      committedUids: uids,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      createdBy: (m['createdBy'] ?? '') as String,
      status: (m['status'] ?? 'open') as String,
      hospitalId: (m['hospitalId'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      fulfilledAt: (m['fulfilledAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    this.id = '',
    required this.fromUid,
    required this.text,
    required this.sentAt,
    this.senderName = '',
    this.lat,
    this.lng,
    this.pending = false,
  });
  final String id, fromUid, text, senderName;
  final DateTime sentAt;

  /// Set for a shared location (text then holds the place name).
  final double? lat, lng;
  bool get isLocation => lat != null && lng != null;

  /// True until the server has acknowledged the message (shown with a clock instead of a time).
  final bool pending;

  /// What a thread row shows for this message.
  String get preview => isLocation ? '📍 Shared a location' : text;

  factory ChatMessage.fromMap(Map<String, dynamic> m, {String id = '', bool pending = false}) => ChatMessage(
        id: id,
        fromUid: (m['fromUid'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        senderName: (m['senderName'] ?? '') as String,
        sentAt: ((m['sentAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
        lat: m['kind'] == 'location' ? (m['lat'] as num?)?.toDouble() : null,
        lng: m['kind'] == 'location' ? (m['lng'] as num?)?.toDouble() : null,
        pending: pending,
      );
}

class NearbyDonor {
  const NearbyDonor({required this.uid, required this.name, required this.bloodGroup, required this.distanceKm, required this.available, required this.donations});
  final String uid, name, bloodGroup;
  final double distanceKm;
  final bool available;
  final int donations;
  String get initials {
    final p = name.split(' ');
    return p.length > 1 ? '${p.first[0]}${p.last[0]}' : name.substring(0, 2).toUpperCase();
  }
}

class DonationRecord {
  const DonationRecord({required this.date, required this.place, required this.note, required this.status});
  final DateTime date;
  final String place, note;

  /// donated | used | deferred
  final String status;

  Map<String, dynamic> toMap() => {'date': Timestamp.fromDate(date), 'place': place, 'note': note, 'status': status};
  factory DonationRecord.fromMap(Map<String, dynamic> m) => DonationRecord(
        date: ((m['date'] as Timestamp?) ?? Timestamp.now()).toDate(),
        place: (m['place'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        status: (m['status'] ?? 'donated') as String,
      );
}
