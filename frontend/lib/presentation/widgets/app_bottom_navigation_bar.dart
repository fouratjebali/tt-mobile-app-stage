import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';

class AppNavigationItemData {
  const AppNavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.reviewCount,
    required this.items,
    required this.onItemSelected,
    this.showAssistantSpace = true,
  });

  final int selectedIndex;
  final int reviewCount;
  final List<AppNavigationItemData> items;
  final ValueChanged<int> onItemSelected;
  final bool showAssistantSpace;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF151C1A) : AppPalette.paper;
    final borderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppPalette.line.withValues(alpha: 0.85);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 78,
        color: surface,
        elevation: 0,
        notchMargin: 9,
        shape:
            showAssistantSpace
                ? const CircularNotchedRectangle()
                : const _CenterDipNotchedShape(),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            data: items[0],
                            selected: selectedIndex == 0,
                            badgeCount: 0,
                            onTap: () => onItemSelected(0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            data: items[1],
                            selected: selectedIndex == 1,
                            badgeCount: 0,
                            onTap: () => onItemSelected(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 78),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            data: items[2],
                            selected: selectedIndex == 2,
                            badgeCount: reviewCount,
                            onTap: () => onItemSelected(2),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            data: items[3],
                            selected: selectedIndex == 3,
                            badgeCount: 0,
                            onTap: () => onItemSelected(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppCenterActionFab extends StatelessWidget {
  const AppCenterActionFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.auto_awesome_rounded,
    this.heroTag = 'centerActionFab',
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
          width: 5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.deepTeal.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: AppPalette.deepTeal,
        foregroundColor: AppPalette.white,
        shape: const CircleBorder(),
        onPressed: onPressed,
        child: Icon(icon, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final AppNavigationItemData data;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppPalette.lavender : AppPalette.deepTeal;
    final inactiveColor =
        isDark
            ? Colors.white.withValues(alpha: 0.58)
            : AppPalette.pine.withValues(alpha: 0.58);

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  bottom: selected ? 2 : -6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 28 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          selected ? data.activeIcon : data.icon,
                          size: selected ? 25 : 24,
                          color: selected ? activeColor : inactiveColor,
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -9,
                            top: -8,
                            child: _NavBadge(count: badgeCount),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        color: selected ? activeColor : inactiveColor,
                        fontSize: 10.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                        height: 1,
                      ),
                      child: Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppPalette.clay,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.paper, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _CenterDipNotchedShape extends NotchedShape {
  const _CenterDipNotchedShape();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    final centerX = host.center.dx;
    final notchRadius = guest?.width != null ? (guest!.width / 2) + 9 : 40.0;
    final notchDepth = 18.0;
    final path = Path()..moveTo(host.left, host.top);
    path.lineTo(centerX - notchRadius, host.top);
    path.cubicTo(
      centerX - notchRadius * 0.55,
      host.top,
      centerX - notchRadius * 0.42,
      host.top + notchDepth,
      centerX,
      host.top + notchDepth,
    );
    path.cubicTo(
      centerX + notchRadius * 0.42,
      host.top + notchDepth,
      centerX + notchRadius * 0.55,
      host.top,
      centerX + notchRadius,
      host.top,
    );
    path.lineTo(host.right, host.top);
    path.lineTo(host.right, host.bottom);
    path.lineTo(host.left, host.bottom);
    path.close();
    return path;
  }
}
