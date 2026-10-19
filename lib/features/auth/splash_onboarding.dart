import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      context.go(ref.read(seenOnboardingProvider) ? '/login' : '/onboarding');
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Scaffold(
      backgroundColor: c.fillBrand,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final d in [0.0, 0.33, 0.66])
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, _) {
                                final t = (_pulse.value + d) % 1;
                                return Opacity(
                                  opacity: (1 - t) * .8,
                                  child: Transform.scale(
                                    scale: .85 + t * 1.35,
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: .6,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .22),
                                  blurRadius: 40,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const RoktoraMark(height: 54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Roktora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'রক্তরা',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Blood, a short walk away.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .95),
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        width: 140,
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withValues(alpha: .28),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Finding donors near you',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ctrl = PageController();
  int _i = 0;

  static const _copy = [
    (
      'Donors within walking distance',
      'Requests reach your neighborhood first, so help can arrive on foot.',
    ),
    (
      'Every hospital is checked',
      'Hospital requests carry a verified badge. Individual requests are screened first — no fake SOS.',
    ),
    (
      'From alert to donation in hours',
      'Alerts only for your blood group and distance. Commit in one tap, then check in with a QR code.',
    ),
  ];

  void _finish() {
    ref.read(seenOnboardingProvider.notifier).markSeen();
    context.go('/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
              child: Row(
                children: [
                  for (var n = 0; n < 3; n++)
                    GestureDetector(
                      onTap: () => _ctrl.animateToPage(
                        n,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        width: n == _i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: n == _i ? c.fillBrand : c.borderStrong,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      backgroundColor: c.surface2,
                      foregroundColor: c.textSecondary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (v) => setState(() => _i = v),
                children: [
                  for (var n = 0; n < 3; n++)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 340,
                            child: [
                              const _RadarArt(),
                              const _VerifiedArt(),
                              const _TimelineArt(),
                            ][n],
                          ),
                          const SizedBox(height: 28),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _copy[n].$1,
                                  style: AppTheme.display(context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _copy[n].$2,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: c.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: PillButton(
                _i == 2 ? 'Get started' : 'Next',
                icon: TablerIcons.arrow_right,
                onPressed: () => _i == 2
                    ? _finish()
                    : _ctrl.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtFrame extends StatelessWidget {
  const _ArtFrame({required this.bg, required this.child});
  final Color bg;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(36),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _DonorChip extends StatelessWidget {
  const _DonorChip(this.ini, this.label);
  final String ini, label;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonorAvatar(ini, size: 30),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RadarArt extends StatelessWidget {
  const _RadarArt();
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    Widget ring(double d, {bool dashed = false, bool fill = false}) =>
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, -.08),
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill ? c.surface1.withValues(alpha: .6) : null,
                border: fill ? null : Border.all(color: c.borderStrong),
              ),
            ),
          ),
        );
    return _ArtFrame(
      bg: c.bgBrand,
      child: Stack(
        children: [
          ring(330),
          ring(220),
          ring(110, fill: true),
          Align(
            alignment: const Alignment(0, -.08),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c.fillBrand,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface1, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: c.fillBrand.withValues(alpha: .18),
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 36,
            top: 50,
            child: _DonorChip('TA', 'O− · 400 m'),
          ),
          const Positioned(
            right: 24,
            top: 130,
            child: _DonorChip('FH', 'O− · 650 m'),
          ),
          const Positioned(
            left: 28,
            top: 210,
            child: _DonorChip('MS', 'O− · 900 m'),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.fillSuccess,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: c.bgSuccess, spreadRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '3 donors within 1 km',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'Live',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedArt extends StatelessWidget {
  const _VerifiedArt();
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return _ArtFrame(
      bg: c.bgAccent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.bgAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        TablerIcons.building_hospital,
                        color: c.textAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Dhanmondi General',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 6),
                            VerifiedBadge(label: null),
                          ],
                        ),
                        Text(
                          'Hospital · 1.2 km',
                          style: TextStyle(fontSize: 12, color: c.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    BloodPill('O−', role: PillRole.danger, height: 28),
                    SizedBox(width: 10),
                    Text(
                      '2 bags for surgery',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Critical · 3 h left',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textDanger,
                      ),
                    ),
                    Text(
                      '1 of 2 committed',
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 28,
            top: 40,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.fillAccent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  Icon(
                    TablerIcons.rosette_discount_check,
                    size: 17,
                    color: c.onFill,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: c.onFill,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineArt extends StatelessWidget {
  const _TimelineArt();
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    Widget step(
      IconData icon,
      String label,
      String time, {
      Color? bg,
      Color? iconBg,
      Color? iconFg,
      Color? fg,
    }) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg ?? c.surface1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: fg),
            ),
          ),
          Text(
            time,
            style: AppTheme.mono(context, color: fg?.withValues(alpha: .9)),
          ),
        ],
      ),
    );
    Widget link() => Container(
      margin: const EdgeInsets.only(left: 34),
      width: 2,
      height: 22,
      color: c.borderStrong,
    );
    return _ArtFrame(
      bg: c.bgSuccess,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            step(
              TablerIcons.bell_ringing,
              'O− alert nearby',
              '10:02',
              iconBg: c.bgDanger,
              iconFg: c.textDanger,
            ),
            link(),
            step(
              TablerIcons.hand_finger,
              'Committed in 1 tap',
              '10:03',
              iconBg: c.bgAccent,
              iconFg: c.textAccent,
            ),
            link(),
            step(
              TablerIcons.qrcode,
              'Checked in, donated',
              '11:52',
              bg: c.fillSuccess,
              iconBg: Colors.white24,
              iconFg: Colors.white,
              fg: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
