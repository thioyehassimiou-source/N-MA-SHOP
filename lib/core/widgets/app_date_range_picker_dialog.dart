import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Ouvre un dialogue moderne, esthétique et entièrement intégré à N'MaShop
/// pour la personnalisation d'une plage de dates (rapports, statistiques, etc.).
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Personnaliser la période',
  String subtitle = 'Sélectionnez une plage de dates pour filtrer vos données',
}) {
  return showDialog<DateTimeRange>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _AppDateRangeDialog(
      initialRange: initialRange,
      firstDate: firstDate ?? DateTime(2023, 1, 1),
      lastDate: lastDate ?? DateTime.now(),
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _AppDateRangeDialog extends StatefulWidget {
  const _AppDateRangeDialog({
    this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.subtitle,
  });

  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String subtitle;

  @override
  State<_AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

enum _DatePreset {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class _AppDateRangeDialogState extends State<_AppDateRangeDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _currentMonth;
  bool _selectingEnd = false;
  _DatePreset _activePreset = _DatePreset.custom;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.initialRange != null) {
      _startDate = DateTime(
        widget.initialRange!.start.year,
        widget.initialRange!.start.month,
        widget.initialRange!.start.day,
      );
      _endDate = DateTime(
        widget.initialRange!.end.year,
        widget.initialRange!.end.month,
        widget.initialRange!.end.day,
      );
    } else {
      _startDate = DateTime(today.year, today.month, 1);
      _endDate = today;
    }

    _currentMonth = DateTime(_endDate.year, _endDate.month, 1);
    _detectPreset();
  }

  void _detectPreset() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(_startDate, today) && _isSameDay(_endDate, today)) {
      _activePreset = _DatePreset.today;
    } else if (_isSameDay(_startDate, yesterday) && _isSameDay(_endDate, yesterday)) {
      _activePreset = _DatePreset.yesterday;
    } else if (_isSameDay(_startDate, today.subtract(const Duration(days: 6))) && _isSameDay(_endDate, today)) {
      _activePreset = _DatePreset.last7Days;
    } else if (_isSameDay(_startDate, today.subtract(const Duration(days: 29))) && _isSameDay(_endDate, today)) {
      _activePreset = _DatePreset.last30Days;
    } else if (_isSameDay(_startDate, DateTime(today.year, today.month, 1)) && _isSameDay(_endDate, today)) {
      _activePreset = _DatePreset.thisMonth;
    } else if (_isSameDay(_startDate, DateTime(today.year, 1, 1)) && _isSameDay(_endDate, today)) {
      _activePreset = _DatePreset.thisYear;
    } else {
      _activePreset = _DatePreset.custom;
    }
  }

  void _applyPreset(_DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime start = today;
    DateTime end = today;

    switch (preset) {
      case _DatePreset.today:
        start = today;
        end = today;
        break;
      case _DatePreset.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        start = yesterday;
        end = yesterday;
        break;
      case _DatePreset.last7Days:
        start = today.subtract(const Duration(days: 6));
        end = today;
        break;
      case _DatePreset.last30Days:
        start = today.subtract(const Duration(days: 29));
        end = today;
        break;
      case _DatePreset.thisMonth:
        start = DateTime(today.year, today.month, 1);
        end = today;
        break;
      case _DatePreset.lastMonth:
        final firstOfThisMonth = DateTime(today.year, today.month, 1);
        final lastOfPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        start = DateTime(lastOfPrevMonth.year, lastOfPrevMonth.month, 1);
        end = lastOfPrevMonth;
        break;
      case _DatePreset.thisYear:
        start = DateTime(today.year, 1, 1);
        end = today;
        break;
      case _DatePreset.custom:
        return;
    }

    setState(() {
      _startDate = start;
      _endDate = end;
      _currentMonth = DateTime(end.year, end.month, 1);
      _selectingEnd = false;
      _activePreset = preset;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDayTapped(DateTime day) {
    if (day.isAfter(widget.lastDate) || day.isBefore(widget.firstDate)) {
      return;
    }

    setState(() {
      if (!_selectingEnd) {
        // Premier clic : définit la date de début
        _startDate = day;
        _endDate = day;
        _selectingEnd = true;
      } else {
        // Deuxième clic : définit la date de fin
        if (day.isBefore(_startDate)) {
          _startDate = day;
          _endDate = day;
          _selectingEnd = true;
        } else {
          _endDate = day;
          _selectingEnd = false;
        }
      }
      _activePreset = _DatePreset.custom;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysCount = _endDate.difference(_startDate).inDays + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final canGoNext = DateTime(_currentMonth.year, _currentMonth.month + 1, 1).isBefore(
      DateTime(widget.lastDate.year, widget.lastDate.month + 1, 1),
    );
    final canGoPrev = _currentMonth.isAfter(
      DateTime(widget.firstDate.year, widget.firstDate.month, 1),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      backgroundColor: context.colors.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête avec gradient N'MaShop ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandNavy, Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.brandOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.brandOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),

            // ── Raccourcis de sélection rapide (Presets) ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetChip(_DatePreset.today, "Aujourd'hui"),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.yesterday, 'Hier'),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.last7Days, '7 jours'),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.last30Days, '30 jours'),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.thisMonth, 'Ce mois-ci'),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.lastMonth, 'Mois dernier'),
                    const SizedBox(width: 8),
                    _buildPresetChip(_DatePreset.thisYear, 'Cette année'),
                  ],
                ),
              ),
            ),

            // ── Résumé visuel de la plage sélectionnée ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Date début
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DU (DÉBUT)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: context.colors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatLongDate(_startDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Flèche centrale
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: context.colors.primary,
                      ),
                    ),

                    // Date fin
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'AU (FIN)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: context.colors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatLongDate(_endDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Badge durée
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brandEmerald.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$daysCount j',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Calendrier interactif N'MaShop ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Navigation mois (Précédent / Mois Année / Suivant)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: canGoPrev ? () => _changeMonth(-1) : null,
                        tooltip: 'Mois précédent',
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'fr').format(_currentMonth).toUpperCase(),
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: canGoNext ? () => _changeMonth(1) : null,
                        tooltip: 'Mois suivant',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // En-têtes jours de semaine
                  Row(
                    children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Grille des jours du mois
                  _buildMonthGrid(today),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Pied de page & Actions ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  // Statut d'aide au clic
                  Text(
                    _selectingEnd
                        ? '👉 Cliquez sur la date de fin'
                        : 'Période : $daysCount jour${daysCount > 1 ? "s" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectingEnd ? AppColors.brandOrange : context.colors.onSurfaceVariant,
                      fontWeight: _selectingEnd ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Annuler',
                      style: TextStyle(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Appliquer la période',
                    icon: Icons.check_circle_rounded,
                    onPressed: () {
                      Navigator.of(context).pop(
                        DateTimeRange(start: _startDate, end: _endDate),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(_DatePreset preset, String label) {
    final isSelected = _activePreset == preset;
    return InkWell(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : context.colors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime today) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Décalage pour le premier jour (Lundi = 1 -> offset = 0)
    final offset = firstDayOfMonth.weekday - 1;

    final totalCells = offset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNumber = cellIndex - offset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 38));
              }

              final cellDate = DateTime(year, month, dayNumber);
              final isToday = _isSameDay(cellDate, today);
              final isStart = _isSameDay(cellDate, _startDate);
              final isEnd = _isSameDay(cellDate, _endDate);
              final isInRange = cellDate.isAfter(_startDate) && cellDate.isBefore(_endDate);
              final isDisabled = cellDate.isAfter(widget.lastDate) || cellDate.isBefore(widget.firstDate);

              return Expanded(
                child: InkWell(
                  onTap: isDisabled ? null : () => _onDayTapped(cellDate),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isStart || isEnd
                          ? context.colors.primary
                          : (isInRange
                              ? context.colors.primary.withValues(alpha: 0.12)
                              : Colors.transparent),
                      borderRadius: isStart && isEnd
                          ? BorderRadius.circular(19)
                          : (isStart
                              ? const BorderRadius.horizontal(left: Radius.circular(19))
                              : (isEnd
                                  ? const BorderRadius.horizontal(right: Radius.circular(19))
                                  : BorderRadius.zero)),
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isStart || isEnd || isToday) ? FontWeight.bold : FontWeight.normal,
                            color: isStart || isEnd
                                ? Colors.white
                                : (isDisabled
                                    ? context.colors.onSurfaceVariant.withValues(alpha: 0.3)
                                    : (isInRange
                                        ? context.colors.primary
                                        : context.colors.onSurface)),
                          ),
                        ),
                        if (isToday && !isStart && !isEnd)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
