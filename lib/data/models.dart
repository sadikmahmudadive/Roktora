import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  final String uid, name, area;
  final String? bloodGroup;
  final bool available, eligible;
  final int donations;
  final DateTime? lastDonation;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return p.length == 1 ? p.first.substring(0, p.first.length.clamp(0, 2)).toUpperCase() : '${p.first[0]}${p.last[0]}'.toUpperCase();
  }

  /// Privacy-first display name, e.g. "Nusrat R."
  String get publicName {
    final p = name.trim().split(RegExp(r'\s+'));
    return p.length == 1 ? p.first : '${p.first} ${p.last[0]}.';
  }

  DonorProfile copyWith({String? name, String? area, String? bloodGroup, bool? available, bool? eligible, int? donations, DateTime? lastDonation}) =>
      DonorProfile(
        uid: uid, name: name ?? this.name, area: area ?? this.area, bloodGroup: bloodGroup ?? this.bloodGroup,
        available: available ?? this.available, eligible: eligible ?? this.eligible,
        donations: donations ?? this.donations, lastDonation: lastDonation ?? this.lastDonation,
      );

  Map<String, dynamic> toMap() => {
        'name': name, 'area': area, 'bloodGroup': bloodGroup, 'available': available, 'eligible': eligible,
        'donations': donations, 'lastDonation': lastDonation == null ? null : Timestamp.fromDate(lastDonation!),
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
  });

  final String id, bloodGroup, title, place, postedBy, note;
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
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.fromUid, required this.text, required this.sentAt});
  final String fromUid, text;
  final DateTime sentAt;

  Map<String, dynamic> toMap() => {'fromUid': fromUid, 'text': text, 'sentAt': Timestamp.fromDate(sentAt)};
  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        fromUid: (m['fromUid'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        sentAt: ((m['sentAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
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
