import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import 'admin_models.dart';

/// Compact button for dense dashboard layouts.
class AdminButton extends StatelessWidget {
  const AdminButton(this.label, {super.key, this.onPressed, this.outlined = false, this.danger = false, this.icon, this.height = 40});
  final String label;
  final VoidCallback? onPressed;
  final bool outlined, danger;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final enabled = onPressed != null;
    final bg = !enabled ? c.surface2 : outlined ? Colors.transparent : c.fillBrand;
    final fg = !enabled ? c.textDisabled : outlined ? (danger ? c.textDanger : c.textPrimary) : c.onFill;
    final text = Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14));
    return Pressable(
      onTap: onPressed,
      scale: .98,
      child: LayoutBuilder(builder: (context, box) {
        // Inside a bounded cell the label may shrink with an ellipsis; in an unbounded row (e.g. next to
        // a text field) flex children assert, so the label just takes its natural width.
        final bounded = box.maxWidth.isFinite;
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: ShapeDecoration(
            color: bg,
            shape: StadiumBorder(side: outlined ? BorderSide(color: danger ? c.borderDanger : c.borderStrong) : BorderSide.none),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
            if (bounded) Flexible(child: text) else text,
          ]),
        );
      }),
    );
  }
}

/// Flat bordered panel used throughout the dashboard (no shadows).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.title, this.trailing});
  final Widget child;
  final EdgeInsets padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(RRadius.card), border: Border.all(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(children: [
              Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              ?trailing,
            ]),
          ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.sub, this.subColor});
  final String label, value, sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(RRadius.card), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 6),
        Text(value, style: AppTheme.display(context, size: 32)),
        const SizedBox(height: 4),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor ?? c.textSecondary)),
      ]),
    );
  }
}

/// Pill-shaped segmented selector.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(RRadius.base), border: Border.all(color: c.borderStrong)),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, o) in options.indexed)
          InkWell(
            onTap: () => onChanged(o.$1),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: o.$1 == value ? c.fillPrimary : null,
                border: i == 0 ? null : Border(left: BorderSide(color: c.borderStrong)),
              ),
              child: Text(o.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: o.$1 == value ? c.onPrimary : c.textPrimary)),
            ),
          ),
      ]),
    );
  }
}

/// Selectable chip in the brand colour.
class PickChip extends StatelessWidget {
  const PickChip(this.label, {super.key, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Pressable(
      onTap: onTap,
      scale: .96,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.bgBrand : c.surface1,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.fillBrand : c.borderStrong, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? c.textBrand : c.textPrimary)),
      ),
    );
  }
}

/// Checkbox in the dashboard's style.
class CheckBoxX extends StatelessWidget {
  const CheckBoxX({super.key, required this.checked, this.size = 22});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: checked ? c.fillBrand : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: c.borderStronger),
      ),
      child: checked ? Icon(Icons.check, size: size - 6, color: Colors.white) : null,
    );
  }
}

PillRole stockRole(InventoryRow r) => switch (r.level) {
      StockLevel.shortage => r.isNegative ? PillRole.danger : PillRole.warning,
      StockLevel.low => PillRole.warning,
      StockLevel.healthy => PillRole.success,
    };

String stockLabel(InventoryRow r) => switch (r.level) { StockLevel.shortage => 'Shortage', StockLevel.low => 'Low', StockLevel.healthy => 'Healthy' };

Color roleColor(RColors c, PillRole r) => switch (r) {
      PillRole.danger => c.textDanger,
      PillRole.warning => c.textWarning,
      PillRole.success => c.textSuccess,
      PillRole.neutral => c.textSecondary,
    };

/// Standard page padding + max width for dashboard screens.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.children, this.title, this.subtitle, this.actions = const []});
  final List<Widget> children;
  final String? title, subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return LayoutBuilder(builder: (context, box) {
      final pad = box.maxWidth >= 700 ? 28.0 : 16.0;
      return ListView(padding: EdgeInsets.fromLTRB(pad, 20, pad, 40), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null) ...[
                Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 240),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title!, style: AppTheme.display(context, size: 32)),
                      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: TextStyle(color: c.textSecondary))),
                    ]),
                  ),
                  ...actions,
                ]),
                const SizedBox(height: 24),
              ],
              ...children,
            ]),
          ),
        ),
      ]);
    });
  }
}

/// Lays children side by side on wide screens and stacks them on narrow ones.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({super.key, required this.children, this.flex, this.breakpoint = 860, this.gap = 16});
  final List<Widget> children;
  final List<int>? flex;
  final double breakpoint, gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < breakpoint) {
        return Column(children: [for (final (i, w) in children.indexed) Padding(padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : gap), child: w)]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, w) in children.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: flex == null ? 1 : flex![i], child: w),
        ],
      ]);
    });
  }
}
