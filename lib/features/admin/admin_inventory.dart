import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});
  @override
  ConsumerState<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  /// -1 = all components, otherwise an index into [bloodComponents].
  int _comp = -1;

  Future<void> _editCell(InventoryRow row, int ci) async {
    final access = ref.read(adminAccessProvider).value;
    if (access == null) return;
    final v = await showDialog<int>(context: context, builder: (_) => _StockDialog(group: row.group, component: bloodComponents[ci], initial: row.part(ci)));
    if (v != null) await ref.read(adminRepositoryProvider).setStock(access.hospitalId, row.group, ci, v);
  }

  Future<void> _logBatch() async {
    final access = ref.read(adminAccessProvider).value;
    if (access == null) return;
    final b = await showDialog<BloodBatch>(context: context, builder: (_) => const _BatchDialog());
    if (b != null) await ref.read(adminRepositoryProvider).addBatch(access.hospitalId, b);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final access = ref.watch(adminAccessProvider).value;
    final inv = ref.watch(inventoryProvider);
    final rows = inv.value ?? const <InventoryRow>[];
    final batches = (ref.watch(batchesProvider).value ?? const <BloodBatch>[])
        .where((b) => _comp < 0 || b.component == bloodComponents[_comp])
        .toList();
    final total = rows.fold(0, (a, r) => a + r.units);

    return AdminPage(
      title: 'Blood inventory',
      subtitle: '$total units on hand',
      actions: [
        Segmented<int>(
          options: [(-1, 'All'), for (final (i, n) in bloodComponents.indexed) (i, n)],
          value: _comp,
          onChanged: (v) => setState(() => _comp = v),
        ),
      ],
      children: [
        Panel(
          title: 'Stock by group',
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv.isLoading ? 'Loading…' : 'No stock recorded yet.', style: TextStyle(color: c.textSecondary)),
                    if (!inv.isLoading && access != null) ...[
                      const SizedBox(height: 12),
                      AdminButton('Set up inventory', icon: TablerIcons.plus, onPressed: () => ref.read(adminRepositoryProvider).seedInventory(access.hospitalId)),
                    ],
                  ]),
                )
              : LayoutBuilder(builder: (context, box) {
                  // Columns need a finite width; on narrow screens the table scrolls sideways instead of squeezing.
                  final width = box.maxWidth < 760 ? 760.0 : box.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: width, child: _StockTable(rows: rows, selected: _comp, onEdit: _editCell)),
                  );
                }),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Expiring batches · ${batches.length}',
          padding: EdgeInsets.zero,
          trailing: AdminButton('Log batch', outlined: true, icon: TablerIcons.plus, height: 34, onPressed: _logBatch),
          child: batches.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('No batches to show.', style: TextStyle(color: c.textSecondary)))
              : Column(children: [for (final (i, b) in batches.indexed) _BatchRow(b, divider: i > 0)]),
        ),
      ],
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.rows, required this.selected, required this.onEdit});
  final List<InventoryRow> rows;
  final int selected;
  final void Function(InventoryRow, int) onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    Widget head(String t, {bool on = false, double? w}) => Container(
          width: w, height: 40, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16),
          color: on ? c.bgBrand : null,
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? c.textPrimary : c.textMuted)),
        );
    return Column(children: [
      Row(children: [
        head('Group', w: 120),
        for (final (i, n) in bloodComponents.indexed) Expanded(child: head(n, on: i == selected)),
        head('Status', w: 200),
      ]),
      for (final r in rows)
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: Row(children: [
            Container(width: 120, height: 52, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16), child: BloodPill(r.group, role: stockRole(r), height: 26)),
            for (var i = 0; i < bloodComponents.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onEdit(r, i),
                  child: Container(
                    height: 52, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: i == selected ? c.bgBrand : null,
                    child: Text('${r.part(i)}', style: TextStyle(fontWeight: FontWeight.w600, color: r.part(i) == 0 ? c.textDanger : c.textPrimary)),
                  ),
                ),
              ),
            Container(
              width: 200, height: 52, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${stockLabel(r)} · ${r.units} of ${r.target}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: roleColor(c, stockRole(r)))),
            ),
          ]),
        ),
    ]);
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow(this.b, {required this.divider});
  final BloodBatch b;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final left = b.daysLeft;
    final crit = left <= 2;
    final color = crit ? c.textDanger : c.textWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: crit ? c.borderDanger : c.borderWarning, width: 2), top: divider ? BorderSide(color: c.border) : BorderSide.none)),
      child: Row(children: [
        Expanded(flex: 3, child: Text(b.id, style: AppTheme.mono(context, size: 12, color: c.textPrimary))),
        BloodPill(b.group, role: roleForGroup(b.group), height: 24, size: 12),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Text(b.component, style: TextStyle(color: c.textSecondary))),
        Expanded(flex: 2, child: Text(DateFormat('d MMM').format(b.expiresAt), style: TextStyle(color: c.textSecondary))),
        SizedBox(width: 90, child: Text(left <= 1 ? 'Tomorrow' : '$left days', style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        SizedBox(width: 90, child: RProgress((left / min(b.shelfLifeDays, 7)).clamp(.04, 1), color: crit ? c.fillDanger : c.fillWarning)),
      ]),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.group, required this.component, required this.initial});
  final String group, component;
  final int initial;
  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late int _v = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.group} · ${widget.component}'),
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleIconButton(icon: TablerIcons.minus, size: 40, label: 'Remove one', onPressed: _v > 0 ? () => setState(() => _v--) : null),
        SizedBox(width: 72, child: Center(child: Text('$_v', style: AppTheme.display(context, size: 32)))),
        CircleIconButton(icon: TablerIcons.plus, size: 40, label: 'Add one', onPressed: () => setState(() => _v++)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _v), child: const Text('Save')),
      ],
    );
  }
}

class _BatchDialog extends StatefulWidget {
  const _BatchDialog();
  @override
  State<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<_BatchDialog> {
  String _group = 'O+';
  int _comp = 0;
  static const _shelf = [35, 42, 365, 5];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a batch'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Blood group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final g in bloodGroups) PickChip(g, selected: g == _group, onTap: () => setState(() => _group = g))]),
          const SizedBox(height: 16),
          const Text('Component', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final (i, n) in bloodComponents.indexed) PickChip(n, selected: i == _comp, onTap: () => setState(() => _comp = i))]),
          const SizedBox(height: 12),
          Text('Shelf life: ${_shelf[_comp]} days', style: TextStyle(fontSize: 12, color: context.rc.textMuted)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            final id = 'B-${DateFormat('yyMM').format(now)}-${(1000 + Random().nextInt(9000))}';
            Navigator.pop(context, BloodBatch(id: id, group: _group, component: bloodComponents[_comp], expiresAt: now.add(Duration(days: _shelf[_comp])), shelfLifeDays: _shelf[_comp]));
          },
          child: const Text('Log batch'),
        ),
      ],
    );
  }
}
