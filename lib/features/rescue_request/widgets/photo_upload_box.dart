import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class PhotoUploadBox extends StatelessWidget {
  const PhotoUploadBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Photo',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          '(optional)',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to add photo',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
