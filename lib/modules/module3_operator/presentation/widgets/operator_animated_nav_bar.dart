import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/attendance_blink_store.dart';

/// PhonePe-style notched bottom navigation bar with 4 tabs (icon + label
/// stacked vertically, always visible) and a floating green QR action
/// button docked in the notch at the center.
///
/// Slot layout: [tab0][tab1] (QR FAB notch) [tab2][tab3].
class OperatorAnimatedNavBar extends StatelessWidget {
  const OperatorAnimatedNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.items,
    this.height = 72,
    this.notchMargin = 8,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<OperatorNavItem> items;
  final double height;
  final double notchMargin;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4,
        'OperatorAnimatedNavBar expects exactly 4 side tabs');
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return BottomAppBar(
      color: OperatorTheme.surface,
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
            const SizedBox(width: 64), // reserved gap for the QR FAB notch
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

class OperatorNavItem {
  const OperatorNavItem({
    required this.icon,
    required this.label,
    this.blink = false,
  });

  final IconData icon;
  final String label;
  final bool blink;
}

class _AnimatedNavTab extends StatelessWidget {
  const _AnimatedNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OperatorNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OperatorTheme.primary : OperatorTheme.mutedText;

    return InkResponse(
      onTap: onTap,
      radius: 38,
      highlightColor: OperatorTheme.surfaceMuted,
      splashColor: OperatorTheme.surfaceMuted,
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
              color: OperatorTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _TabIcon(item: item, color: color, selected: selected),
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

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.item,
    required this.color,
    required this.selected,
  });

  final OperatorNavItem item;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: Icon(item.icon, color: color, size: 22),
    );

    if (!item.blink) return icon;

    return ValueListenableBuilder<bool>(
      valueListenable: AttendanceBlinkStore.notifier,
      builder: (context, isBlinking, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            if (isBlinking)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: OperatorTheme.attendanceAlert,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: OperatorTheme.attendanceAlert
                            .withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Amber QR action button — primary CTA, intentionally the most prominent
/// element on screen. Sits in the BottomAppBar notch via centerDocked.
class OperatorQrFab extends StatefulWidget {
  const OperatorQrFab({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  State<OperatorQrFab> createState() => _OperatorQrFabState();
}

class _OperatorQrFabState extends State<OperatorQrFab>
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
                  color: OperatorTheme.accent.withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Material(
          color: OperatorTheme.accent,
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: OperatorTheme.accentDeep.withValues(alpha: 0.55),
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
                  gradient: OperatorTheme.accentGradient,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
