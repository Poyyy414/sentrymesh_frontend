import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class AlertFilterTabs extends StatelessWidget {
  const AlertFilterTabs({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (label: 'All', icon: Icons.grid_view_rounded),
    (label: 'Warnings', icon: Icons.warning_amber_rounded),
    (label: 'Advisories', icon: Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDDE6F0))),
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = selectedIndex == index;

          return Expanded(
            child: InkWell(
              key: Key('alert_filter_$index'),
              onTap: () => onChanged(index),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: selected
                              ? AppTheme.signalBlue
                              : const Color(0xFF5F7188),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.signalBlue
                                  : const Color(0xFF5F7188),
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 3,
                    width: selected ? 86 : 0,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.signalBlue
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
