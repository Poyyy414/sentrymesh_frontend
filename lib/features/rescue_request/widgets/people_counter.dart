import 'package:flutter/material.dart';

class PeopleCounter extends StatefulWidget {
  const PeopleCounter({super.key});

  @override
  State<PeopleCounter> createState() => _PeopleCounterState();
}

class _PeopleCounterState extends State<PeopleCounter> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'People Needing Help',
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3E8EF)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _count > 1 ? () => setState(() => _count--) : null,
                    tooltip: 'Decrease people count',
                    icon: const Icon(Icons.remove, size: 17),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$_count',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _count++),
                    tooltip: 'Increase people count',
                    icon: const Icon(Icons.add, size: 17),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 3, right: 8),
            child: Text(
              '(including you)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}
