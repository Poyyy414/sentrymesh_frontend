import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/custom_button.dart';
import '../../data/models/rescue_request_model.dart';
import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';
import 'widgets/emergency_contacts_list.dart';
import 'widgets/emergency_type_dropdown.dart';
import 'widgets/people_counter.dart';

class RescueRequestScreen extends StatefulWidget {
  const RescueRequestScreen({super.key});

  @override
  State<RescueRequestScreen> createState() => _RescueRequestScreenState();
}

class _RescueRequestScreenState extends State<RescueRequestScreen> {
  final _descriptionController = TextEditingController();
  String _emergencyType = 'Medical Emergency';
  int _people = 1;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty || _isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the emergency first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final dependencies = AppDependenciesScope.of(context);

    try {
      double? latitude;
      double? longitude;
      try {
        final location = await dependencies.locationService.currentLocation();
        latitude = location.latitude;
        longitude = location.longitude;
      } catch (_) {
        // A request can still be submitted when GPS is unavailable.
      }

      final request = RescueRequestModel(
        id: '',
        userId: dependencies.authRepository.currentUser?.id,
        emergencyType: switch (_emergencyType) {
          'Flood Rescue' => HazardType.flood,
          'Landslide Rescue' => HazardType.landslide,
          'Supply Request' => HazardType.infrastructure,
          _ => HazardType.medical,
        },
        peopleNeedingHelp: _people,
        description: description,
        status: RescueStatus.pending,
        createdAt: DateTime.now().toUtc(),
        latitude: latitude,
        longitude: longitude,
        locationLabel: latitude == null ? null : 'Resident GPS',
      );
      await dependencies.rescueRepository.submitRequest(request);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rescue request submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit request: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
            Text(
              'Emergency Type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            EmergencyTypeDropdown(onChanged: (value) => _emergencyType = value),
            const SizedBox(height: 18),
            PeopleCounter(onChanged: (value) => _people = value),
            const SizedBox(height: 18),
            Text('Description', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 5,
              maxLength: 250,
              decoration: InputDecoration(
                hintText:
                    'Elderly person with high fever and difficulty breathing. Need immediate medical assistance.',
              ),
            ),
            const SizedBox(height: 18),
            SentryButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit Request',
              onPressed: _isSubmitting ? null : _submit,
            ),
            const SizedBox(height: 22),
            const EmergencyContactsList(),
          ],
        ),
      ),
    );
  }
}
