import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Animated illustrations for the three onboarding slides. Each one plays a short entrance when its slide
/// appears, then idles with gentle looping motion. Reduced-motion settings (and widget tests) get the
/// finished, still picture.

double _seg(
  double t,
  double a,
  double b, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

double _wave(double l, [double phase = 0, double cycles = 1]) =>
    math.sin((l * cycles + phase) * 2 * math.pi);

/// Drives an entrance value (0 -> 1, once) and a loop value (0 -> 1, repeating).
class _Stage extends StatefulWidget {
  const _Stage({required this.builder});
  final Widget Function(BuildContext context, double intro, double loop)
  builder;
  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion =
        !MediaQuery.disableAnimationsOf(context) &&
        !Platform.environment.containsKey('FLUTTER_TEST');
    if (motion) {
      _intro.forward();
      _loop.repeat();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_intro, _loop]),
    builder: (context, _) => widget.builder(context, _intro.value, _loop.value),
  );
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

/// Fades and scales a child in, anchored at its centre.
Widget _pop(double s, Widget child, {double dy = 0}) => Opacity(
  opacity: s.clamp(0.0, 1.0),
  child: Transform.translate(
    offset: Offset(0, dy),
    child: Transform.scale(scale: .6 + .4 * s, child: child),
  ),
);

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

// ---------------------------------------------------------------------------------------------------------------
// 1. Donors within walking distance: a radar that sweeps, with donors popping up around you.

class RadarArt extends StatelessWidget {
  const RadarArt({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    const centre = Alignment(0, -.08);

    Widget ring(double d, {bool fill = false}) => Positioned.fill(
      child: Align(
        alignment: centre,
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

    return _Stage(
      builder: (context, t, l) {
        Widget chip(
          int i,
          double left,
          double? right,
          double top,
          String ini,
          String label,
        ) {
          final s = _seg(t, .2 + i * .18, .55 + i * .18, Curves.easeOutBack);
          return Positioned(
            left: right == null ? left : null,
            right: right,
            top: top,
            child: _pop(
              s,
              Transform.translate(
                offset: Offset(0, _wave(l, i * .33) * 3.5),
                child: _DonorChip(ini, label),
              ),
            ),
          );
        }

        return _ArtFrame(
          bg: c.bgBrand,
          child: Stack(
            children: [
              ring(330),
              ring(220),
              ring(110, fill: true),
              // Radar sweep.
              Positioned.fill(
                child: Align(
                  alignment: centre,
                  child: Opacity(
                    opacity: _seg(t, 0, .5),
                    child: Transform.rotate(
                      angle: l * 2 * math.pi,
                      child: Container(
                        width: 330,
                        height: 330,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              c.fillBrand.withValues(alpha: .22),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0, .2, .2, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Pulses leaving your position.
              for (final d in const [0.0, .5])
                Positioned.fill(
                  child: Align(
                    alignment: centre,
                    child: Builder(
                      builder: (_) {
                        final p = (l + d) % 1;
                        return Opacity(
                          opacity: (1 - p) * .5 * _seg(t, 0, .3),
                          child: Container(
                            width: 22 + p * 300,
                            height: 22 + p * 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.fillBrand,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Align(
                alignment: centre,
                child: Transform.scale(
                  scale: _seg(t, 0, .35, Curves.easeOutBack),
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
                          spreadRadius: 8 + _wave(l) * 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              chip(0, 36, null, 50, 'TA', 'O− · 400 m'),
              chip(1, 0, 24, 130, 'FH', 'O− · 650 m'),
              chip(2, 28, null, 210, 'MS', 'O− · 900 m'),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Opacity(
                  opacity: _seg(t, .1, .5),
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - _seg(t, .1, .5))),
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
                                BoxShadow(
                                  color: c.bgSuccess,
                                  spreadRadius: 3 + _wave(l, 0, 2) * 1.5,
                                ),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// 2. Every hospital is checked: a request card slides in and a Verified stamp lands on it.

class VerifiedArt extends StatelessWidget {
  const VerifiedArt({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return _Stage(
      builder: (context, t, l) {
        final card = _seg(t, 0, .4);
        final stamp = _seg(t, .4, .95, Curves.elasticOut);
        final bar = _seg(t, .5, 1, Curves.easeInOut);
        return _ArtFrame(
          bg: c.bgAccent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft drifting background blobs.
              Positioned(
                left: -30 + _wave(l) * 10,
                top: 40 + _wave(l, .25) * 10,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.fillAccent.withValues(alpha: .08),
                  ),
                ),
              ),
              Positioned(
                right: -40 + _wave(l, .5) * 10,
                bottom: 20 + _wave(l, .75) * 10,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.fillAccent.withValues(alpha: .08),
                  ),
                ),
              ),
              Opacity(
                opacity: card,
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - card) + _wave(l) * 2),
                  child: Container(
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
                                Row(
                                  children: [
                                    const Text(
                                      'Dhanmondi General',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Transform.scale(
                                      scale: .6 + .4 * stamp.clamp(0.0, 1.4),
                                      child: const VerifiedBadge(label: null),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Hospital · 1.2 km',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Transform.scale(
                              scale: 1 + .05 * math.max(0, _wave(l, 0, 2)),
                              child: const BloodPill(
                                'O−',
                                role: PillRole.danger,
                                height: 28,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '2 bags for surgery',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Commitment progress: 1 of 2.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ColoredBox(color: c.border),
                                ),
                                FractionallySizedBox(
                                  widthFactor: .5 * bar,
                                  child: ColoredBox(color: c.fillSuccess),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The "Verified" stamp lands with a bounce, then bobs.
              Positioned(
                right: 28,
                top: 40,
                child: Opacity(
                  opacity: _seg(t, .4, .6),
                  child: Transform.translate(
                    offset: Offset(0, _wave(l, .1) * 3),
                    child: Transform.rotate(
                      angle: -.12 * (1 - stamp.clamp(0.0, 1.0)),
                      child: Transform.scale(
                        scale: stamp.clamp(0.0, 1.3),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: c.fillAccent,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: c.fillAccent.withValues(alpha: .35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// 3. From alert to donation: three steps appear in order, linked by lines that draw themselves.

class TimelineArt extends StatelessWidget {
  const TimelineArt({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return _Stage(
      builder: (context, t, l) {
        Widget step(
          int i,
          Widget icon,
          String label,
          String time, {
          Color? bg,
          Color? iconBg,
          Color? fg,
        }) {
          final s = _seg(t, i * .27, i * .27 + .3);
          return Opacity(
            opacity: s,
            child: Transform.translate(
              offset: Offset(28 * (1 - s), 0),
              child: Container(
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
                      child: icon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: AppTheme.mono(
                        context,
                        color: fg?.withValues(alpha: .9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget link(int i) => Container(
          margin: const EdgeInsets.only(left: 34),
          alignment: Alignment.topCenter,
          width: 2,
          height: 22,
          child: FractionallySizedBox(
            heightFactor: _seg(t, i * .27 + .18, i * .27 + .36),
            child: ColoredBox(
              color: c.borderStrong,
              child: const SizedBox(width: 2),
            ),
          ),
        );

        // The bell rings in bursts; the finger taps; the QR step glows when complete.
        final burst = math.max(0.0, _wave(l, 0, 1));
        final bell = Transform.rotate(
          angle: burst * _wave(l, 0, 7) * .35,
          child: Icon(TablerIcons.bell_ringing, size: 18, color: c.textDanger),
        );
        final tap = Transform.translate(
          offset: Offset(0, 2.5 * math.max(0, _wave(l, .25, 2))),
          child: Icon(TablerIcons.hand_finger, size: 18, color: c.textAccent),
        );
        final qr = Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - l) * .5 * _seg(t, .7, 1),
              child: Container(
                width: 38 + 22 * l,
                height: 38 + 22 * l,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
            const Icon(TablerIcons.qrcode, size: 18, color: Colors.white),
          ],
        );

        return _ArtFrame(
          bg: c.bgSuccess,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                step(0, bell, 'O− alert nearby', '10:02', iconBg: c.bgDanger),
                link(0),
                step(1, tap, 'Committed in 1 tap', '10:03', iconBg: c.bgAccent),
                link(1),
                step(
                  2,
                  qr,
                  'Checked in, donated',
                  '11:52',
                  bg: c.fillSuccess,
                  iconBg: Colors.white24,
                  fg: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
