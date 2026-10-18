import 'package:flutter/material.dart';

/// Single place to edit the event details shown in every station header.
class EventInfo {
  static const String academicYear = 'AY 2026-2027';
  static const String title = 'Internship Seminar & Career Readiness Orientation';
  static const String dateLabel = 'October 24, 2026';
  static const String venue = 'Saint Louis University, AVR';
}

class AppColors {
  static const Color navy = Color(0xFF0F1B45);
  static const Color navyDark = Color(0xFF0A1333);
  static const Color navyCard = Color(0xFF141F4F);
  static const Color navyBorder = Color(0xFF26346B);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEEF2FF);
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldSoft = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color blue = Color(0xFF1D4ED8);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F3FF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
}

class HeaderStat {
  final String label;
  final String value;
  final String? valueNote; // e.g. "(64%)"
  final String rightLabel; // e.g. "12 Online"
  final IconData icon;
  final Color accent;

  const HeaderStat({
    required this.label,
    required this.value,
    this.valueNote,
    required this.rightLabel,
    required this.icon,
    required this.accent,
  });
}

class StationTabData {
  final String label;
  final IconData icon;
  final String? badge;

  const StationTabData({required this.label, required this.icon, this.badge});
}

/// Dark navy event banner + stat cards + tab strip.
/// Tabs and stats are optional so Admin and Finance can reuse the same shell.
class StationHeader extends StatelessWidget {
  final String stationLabel;
  final IconData stationIcon;
  final Color stationAccent;
  final List<Widget> actions;
  final List<HeaderStat> stats;
  final List<StationTabData> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabChanged;

  const StationHeader({
    super.key,
    required this.stationLabel,
    required this.stationIcon,
    required this.stationAccent,
    this.actions = const [],
    this.stats = const [],
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final titleBlock = _titleBlock();
                  final actionBlock = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: wide ? WrapAlignment.end : WrapAlignment.start,
                    children: [_stationPill(), ...actions],
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 20),
                        Flexible(child: actionBlock),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 16),
                      actionBlock,
                    ],
                  );
                },
              ),
            ),
            if (stats.isNotEmpty || tabs.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.navyDark,
                padding: EdgeInsets.fromLTRB(
                  28,
                  stats.isNotEmpty ? 18 : 10,
                  28,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stats.isNotEmpty) _statsRow(),
                    if (stats.isNotEmpty && tabs.isNotEmpty)
                      const SizedBox(height: 16),
                    if (tabs.isNotEmpty) _tabStrip(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _titleBlock() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.indigo,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.apartment_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      EventInfo.academicYear,
                      style: TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _metaItem(Icons.calendar_today_outlined, EventInfo.dateLabel),
                  _metaItem(Icons.location_on_outlined, EventInfo.venue),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                EventInfo.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _stationPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: stationAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Icon(stationIcon, size: 16, color: Colors.white70),
          const SizedBox(width: 7),
          Text(
            stationLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 980
            ? stats.length
            : (c.maxWidth >= 560 ? 2 : 1);
        const gap = 16.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats) SizedBox(width: w, child: _StatCard(s)),
          ],
        );
      },
    );
  }

  Widget _tabStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabButton(
              data: tabs[i],
              selected: i == selectedTab,
              onTap: () => onTabChanged?.call(i),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final HeaderStat stat;
  const _StatCard(this.stat);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stat.rightLabel,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stat.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              if (stat.valueNote != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    stat.valueNote!,
                    style: TextStyle(
                      color: stat.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(stat.icon, size: 20, color: stat.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final StationTabData data;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.indigo : const Color(0xFFCBD5E1);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              data.label,
              style: TextStyle(
                color: fg,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (data.badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.indigoSoft
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.badge!,
                  style: TextStyle(
                    color: selected ? AppColors.indigo : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small rounded label used for IDs, registration type, section, payment, etc.
class TagChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final bool mono;

  const TagChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}

/// Rounded status badge with an icon (pending / in hall / etc.).
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Buttons that sit on the navy header.
class HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? fillColor;

  const HeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: fillColor ?? AppColors.emerald,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppColors.navyBorder),
        backgroundColor: AppColors.navyCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 19),
        tooltip: tooltip,
      ),
    );
  }
}
