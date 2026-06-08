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

  static const _labels = ['All', 'Warnings', 'Advisories'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = selectedIndex == index;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Material(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(index),
                    child: Center(
                      child: Text(
                        _labels[index],
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: selected
                                  ? AppTheme.signalBlue
                                  : AppTheme.textMuted,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
