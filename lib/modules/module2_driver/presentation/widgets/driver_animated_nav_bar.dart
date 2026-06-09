import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/driver_theme.dart';

/// Driver bottom navigation bar. Shares the operator's exact visual treatment
/// — a [BottomAppBar] with the animated indicator pill above each icon, the
/// easeOutBack icon scale, and the icon+label stack — but with a FLAT shape
/// and 4 evenly-spaced tabs. There is no centered QR FAB / notch (the driver
/// has no scan action), so the slots are simply distributed across the width.
///
/// Slot layout: [tab0][tab1][tab2][tab3].
class DriverAnimatedNavBar extends StatelessWidget {
  const DriverAnimatedNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.items,
    this.height = 72,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<DriverNavItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'DriverAnimatedNavBar expects exactly 4 tabs');
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return BottomAppBar(
      color: DriverTheme.surface,
      elevation: 0,
      // Flat — no CircularNotchedRectangle, no FAB notch.
      shape: null,
      padding: EdgeInsets.zero,
      height: height + bottomInset,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset * .35 : 0),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) Expanded(child: _slot(i)),
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

class DriverNavItem {
  const DriverNavItem({
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

  final DriverNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DriverTheme.primary : DriverTheme.mutedText;

    return InkResponse(
      onTap: onTap,
      radius: 38,
      highlightColor: DriverTheme.surfaceMuted,
      splashColor: DriverTheme.surfaceMuted,
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
              color: DriverTheme.accent,
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
