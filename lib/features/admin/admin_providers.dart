import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

/// Overridden in main() (and tests) with the Firebase or demo dashboard backend.
final adminRepositoryProvider = Provider<AdminRepository>((ref) => throw UnimplementedError());

/// Non-null only for signed-in hospital staff.
final adminAccessProvider = StreamProvider<AdminAccess?>((ref) => ref.watch(adminRepositoryProvider).access());

String? _hid(Ref ref) => ref.watch(adminAccessProvider).value?.hospitalId;

final hospitalProvider = StreamProvider<HospitalProfile?>((ref) {
  final id = _hid(ref);
  return id == null ? const Stream.empty() : ref.watch(adminRepositoryProvider).hospital(id);
});

final inventoryProvider = StreamProvider<List<InventoryRow>>((ref) {
  final id = _hid(ref);
  return id == null ? const Stream.empty() : ref.watch(adminRepositoryProvider).inventory(id);
});

final batchesProvider = StreamProvider<List<BloodBatch>>((ref) {
  final id = _hid(ref);
  return id == null ? const Stream.empty() : ref.watch(adminRepositoryProvider).batches(id);
});

final hospitalRequestsProvider = StreamProvider<List<BloodRequest>>((ref) {
  final id = _hid(ref);
  return id == null ? const Stream.empty() : ref.watch(adminRepositoryProvider).hospitalRequests(id);
});

final checkinsProvider = StreamProvider<List<CheckIn>>((ref) {
  final id = _hid(ref);
  return id == null ? const Stream.empty() : ref.watch(adminRepositoryProvider).checkins(id);
});

final donorDirectoryProvider = FutureProvider.autoDispose<List<DonorEntry>>((ref) => ref.watch(adminRepositoryProvider).directory());

class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.weekly;
  void set(ReportPeriod p) => state = p;
}

final reportPeriodProvider = NotifierProvider<ReportPeriodNotifier, ReportPeriod>(ReportPeriodNotifier.new);
