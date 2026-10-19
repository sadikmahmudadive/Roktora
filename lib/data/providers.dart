import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'repository.dart';

/// Overridden in main() with the Firebase or demo implementation.
final repositoryProvider = Provider<RoktoraRepository>((ref) => throw UnimplementedError());

final authProvider = StreamProvider<String?>((ref) => ref.watch(repositoryProvider).authChanges());
final profileProvider = StreamProvider<DonorProfile?>((ref) => ref.watch(repositoryProvider).profile());
final requestsProvider = StreamProvider<List<BloodRequest>>((ref) => ref.watch(repositoryProvider).requests());
final requestProvider =
    StreamProvider.family<BloodRequest?, String>((ref, id) => ref.watch(repositoryProvider).request(id));
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, id) => ref.watch(repositoryProvider).messages(id));
final donationsProvider = StreamProvider<List<DonationRecord>>((ref) => ref.watch(repositoryProvider).donations());
final nearbyDonorsProvider = FutureProvider<List<NearbyDonor>>((ref) => ref.watch(repositoryProvider).nearbyDonors());

/// Persists light/dark/system choice.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString('themeMode');
      if (v != null) state = ThemeMode.values.byName(v);
    });
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    (await SharedPreferences.getInstance()).setString('themeMode', m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Whether the user finished onboarding slides on this device.
class SeenOnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void markSeen() => state = true;
}

final seenOnboardingProvider = NotifierProvider<SeenOnboardingNotifier, bool>(SeenOnboardingNotifier.new);

String timeLeft(DateTime deadline) {
  final d = deadline.difference(DateTime.now());
  if (d.isNegative) return 'Expired';
  if (d.inHours >= 24) return '${d.inDays} d';
  if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}
