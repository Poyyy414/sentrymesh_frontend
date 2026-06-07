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
      height: 48,
      color: Colors.white,
      child: Row(
        children: List.generate(_labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        _labels[index],
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: selected
                                  ? AppTheme.signalBlue
                                  : AppTheme.textPrimary,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 56,
                    color: selected ? AppTheme.signalBlue : Colors.transparent,
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
