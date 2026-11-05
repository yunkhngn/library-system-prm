import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'pagination_bar.dart';
import 'state_views.dart';

class StaffColumn<T> {
  const StaffColumn(
      {required this.header, required this.cell, this.minWidth = 100});

  final String header;
  final Widget Function(T row) cell;
  final double minWidth;
}

/// Wide screens: a bordered data table. Phone widths: a card per row.
class StaffTable<T> extends StatelessWidget {
  const StaffTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.onPageChanged,
    required this.empty,
    this.onRowTap,
    this.rowActions,
  });

  final List<StaffColumn<T>> columns;
  final List<T> rows;
  final int page;
  final int size;
  final int totalElements;
  final ValueChanged<int> onPageChanged;
  final Widget empty;
  final ValueChanged<T>? onRowTap;
  final List<Widget> Function(T row)? rowActions;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Card(child: empty);

    final compact =
        MediaQuery.sizeOf(context).width < AppSizes.compactBreakpoint;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) _CardList(this) else _WideTable(this),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PaginationBar(
              page: page,
              size: size,
              totalElements: totalElements,
              onPageChanged: onPageChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideTable<T> extends StatelessWidget {
  const _WideTable(this.table);
  final StaffTable<T> table;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingTextStyle: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            dataTextStyle: AppTypography.bodyM,
            headingRowColor: WidgetStatePropertyAll(AppColors.neutralSurface),
            showCheckboxColumn: false,
            columns: [
              for (final c in table.columns) DataColumn(label: Text(c.header)),
              if (table.rowActions != null) const DataColumn(label: Text('')),
            ],
            rows: [
              for (final row in table.rows)
                DataRow(
                  onSelectChanged: table.onRowTap == null
                      ? null
                      : (_) => table.onRowTap!(row),
                  cells: [
                    for (final c in table.columns) DataCell(c.cell(row)),
                    if (table.rowActions != null)
                      DataCell(Row(children: table.rowActions!(row))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardList<T> extends StatelessWidget {
  const _CardList(this.table);
  final StaffTable<T> table;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < table.rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          InkWell(
            onTap: table.onRowTap == null
                ? null
                : () => table.onRowTap!(table.rows[i]),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in table.columns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              c.header,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(child: c.cell(table.rows[i])),
                        ],
                      ),
                    ),
                  if (table.rowActions != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Wrap(
                          spacing: AppSpacing.sm,
                          children: table.rowActions!(table.rows[i])),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StaffEmpty extends StatelessWidget {
  const StaffEmpty(
      {super.key,
      required this.title,
      this.message,
      this.icon = Icons.inbox_outlined});

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, title: title, message: message);
}
