import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'motion.dart';

const _dropPath =
    'M875 450C855 560 880 650 960 760C1040 870 1212 980 1212 1130C1212 1320 1060 1470 875 1470C690 1470 530 1320 530 1120C530 1030 560 930 597 852C555 960 545 1080 625 1180C655 1218 680 1240 710 1240C745 1240 765 1200 745 1170C735 1150 715 1138 700 1125C640 1070 615 990 620 900C630 740 760 570 875 450Z';

/// The Roktora blood-drop mark.
class RoktoraMark extends StatelessWidget {
  const RoktoraMark({super.key, this.height = 26, this.color});
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.rc.fillBrand;
    final hex = '#${c.toARGB32().toRadixString(16).substring(2)}';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="520 440 702 1040"><path fill="$hex" d="$_dropPath"/></svg>',
      height: height,
    );
  }
}

enum PillRole { danger, warning, success, neutral }

/// Rh-negative groups read as danger, B/O positives as warning, others success.
PillRole roleForGroup(String g) =>
    g.endsWith('−') || g.endsWith('-') ? PillRole.danger : (g.startsWith('B') || g.startsWith('O') ? PillRole.warning : PillRole.success);

class BloodPill extends StatelessWidget {
  const BloodPill(this.label, {super.key, this.role = PillRole.neutral, this.size = 13, this.height = 26});
  final String label;
  final PillRole role;
  final double size, height;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final (bg, fg) = switch (role) {
      PillRole.danger => (c.bgDanger, c.textDanger),
      PillRole.warning => (c.bgWarning, c.textWarning),
      PillRole.success => (c.bgSuccess, c.textSuccess),
      PillRole.neutral => (c.surface2, c.textSecondary),
    };
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(RRadius.pill)),
      child: Text(label, style: TextStyle(color: fg, fontSize: size, fontWeight: FontWeight.w600)),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.label = 'Verified hospital'});
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 16, height: 16,
        decoration: BoxDecoration(color: c.fillAccent, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 11, color: c.onFill),
      ),
      if (label != null) ...[
        const SizedBox(width: 6),
        Text(label!, style: TextStyle(color: c.textAccent, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ]);
  }
}

class DonorAvatar extends StatelessWidget {
  const DonorAvatar(this.initials, {super.key, this.size = 40, this.online = false});
  final String initials;
  final double size;
  final bool online;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return SizedBox(
      width: size, height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size, height: size, alignment: Alignment.center,
          decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle, border: Border.all(color: c.border)),
          child: Text(initials, style: TextStyle(fontSize: size * .35, fontWeight: FontWeight.w600)),
        ),
        if (online)
          Positioned(
            right: -1, bottom: -1,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: c.fillSuccess, shape: BoxShape.circle, border: Border.all(color: c.surface1, width: 2)),
            ),
          ),
      ]),
    );
  }
}

/// Big pill action button; brand fill by default.
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, this.onPressed, this.height = 58, this.outlined = false, this.danger = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool outlined, danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final enabled = onPressed != null;
    final bg = !enabled ? c.surface2 : outlined ? Colors.transparent : c.fillBrand;
    final fg = !enabled ? c.textDisabled : outlined ? (danger ? c.textDanger : c.textPrimary) : c.onFill;
    return Pressable(
      onTap: onPressed,
      scale: .98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: height,
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(side: outlined ? BorderSide(color: danger ? c.borderDanger : c.borderStrong) : BorderSide.none),
          shadows: enabled && !outlined
              ? [BoxShadow(color: c.fillBrand.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 8))]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -.1)),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: fg, size: 18)],
        ]),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onPressed, this.size = 44, this.label, this.filled = true});
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? label;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Semantics(
      label: label, button: true,
      child: Pressable(
        onTap: onPressed,
        scale: .92,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: filled ? c.surface1 : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: filled ? c.border : c.borderStrong),
          ),
          child: Icon(icon, size: 20, color: onPressed == null ? c.textDisabled : c.textPrimary),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.stripe, this.radius = 22, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? stripe;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final inner = Padding(padding: padding, child: child);
    final card = Container(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: stripe == null
          ? inner
          : DecoratedBox(decoration: BoxDecoration(border: Border(left: BorderSide(color: stripe!, width: 2))), child: inner),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: .985, child: card);
  }
}

class RProgress extends StatelessWidget {
  const RProgress(this.value, {super.key, this.color});
  final double value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1), minHeight: 6,
        backgroundColor: c.progressTrack, valueColor: AlwaysStoppedAnimation(color ?? c.fillBrand),
      ),
    );
  }
}

class RSwitch extends StatelessWidget {
  const RSwitch({super.key, required this.value, required this.onChanged, this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Semantics(
      label: label, toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 52, height: 32, padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: value ? c.fillSuccess : c.borderStrong, borderRadius: BorderRadius.circular(RRadius.pill)),
          child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppTheme.display(context)),
      if (subtitle != null) ...[
        const SizedBox(height: 10),
        Text(subtitle!, style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.4)),
      ],
    ]);
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, required this.icon, required this.bg, required this.fg});
  final String text;
  final IconData icon;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: fg, size: 20), const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
      );
}
