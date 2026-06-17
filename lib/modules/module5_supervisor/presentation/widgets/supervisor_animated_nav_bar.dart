import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// PhonePe-style notched bottom navigation bar with 4 tabs (icon + label
/// stacked vertically, always visible) and a floating green action button
/// docked in the notch at the center. Mirrors OperatorAnimatedNavBar exactly
/// so the supervisor shell is indistinguishable from operator/driver.
///
/// Slot layout: [tab0][tab1] (FAB notch) [tab2][tab3].
class SupervisorAnimatedNavBar extends StatelessWidget {
  const SupervisorAnimatedNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.items,
    this.height = 72,
    this.notchMargin = 8,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<SupervisorNavItem> items;
  final double height;
  final double notchMargin;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4,
        'SupervisorAnimatedNavBar expects exactly 4 side tabs');
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return BottomAppBar(
      color: SupervisorTheme.surface,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: notchMargin,
      padding: EdgeInsets.zero,
      height: height + bottomInset,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset * .35 : 0),
        child: Row(
          children: [
            Expanded(child: _slot(0)),
            Expanded(child: _slot(1)),
            const SizedBox(width: 64), // reserved gap for the FAB notch
            Expanded(child: _slot(2)),
            Expanded(child: _slot(3)),
          ],
        ),
      ),
    );
  }

  Widget _slot(int index) => _AnimatedNavTab(
        item: items[index],
        selected: index == activeIndex,
        onTap: () => onTabSelected(index),
      );
}

class SupervisorNavItem {
  const SupervisorNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _AnimatedNavTab extends StatelessWidget {
  const _AnimatedNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SupervisorNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? SupervisorTheme.primary : SupervisorTheme.mutedText;

    return InkResponse(
      onTap: onTap,
      radius: 38,
      highlightColor: SupervisorTheme.surfaceMuted,
      splashColor: SupervisorTheme.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active indicator pill above the icon (slides in on select)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: selected ? 22 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: SupervisorTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Icon(item.icon, color: color, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green pulsing action button docked in the BottomAppBar notch via
/// centerDocked. For the supervisor this is a "Today" refresh-and-jump action
/// (no QR scanning) — preserving the identical notched silhouette.
class SupervisorFab extends StatefulWidget {
  const SupervisorFab({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.today_rounded,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  State<SupervisorFab> createState() => _SupervisorFabState();
}

class _SupervisorFabState extends State<SupervisorFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64 + (12 * t),
                height: 64 + (12 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      SupervisorTheme.accent.withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Material(
          color: SupervisorTheme.accent,
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: SupervisorTheme.accentDeep.withValues(alpha: 0.55),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onPressed,
            child: Tooltip(
              message: widget.label,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SupervisorTheme.accentGradient,
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
