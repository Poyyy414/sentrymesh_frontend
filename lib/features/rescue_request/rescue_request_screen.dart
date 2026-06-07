import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/custom_button.dart';
import 'widgets/emergency_contacts_list.dart';
import 'widgets/emergency_type_dropdown.dart';
import 'widgets/people_counter.dart';
import 'widgets/photo_upload_box.dart';

class RescueRequestScreen extends StatelessWidget {
  const RescueRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rescue Request')),
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Emergency Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const EmergencyTypeDropdown(),
            const SizedBox(height: 18),
            const PeopleCounter(),
            const SizedBox(height: 18),
            Text('Description', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const TextField(
              minLines: 4,
              maxLines: 5,
              maxLength: 250,
              decoration: InputDecoration(
                hintText:
                    'Elderly person with high fever and difficulty breathing. Need immediate medical assistance.',
              ),
            ),
            const SizedBox(height: 8),
            const PhotoUploadBox(),
            const SizedBox(height: 18),
            SentryButton(
              label: 'Submit Request',
              onPressed: () {},
            ),
            const SizedBox(height: 22),
            const EmergencyContactsList(),
          ],
        ),
      ),
    );
  }
}
