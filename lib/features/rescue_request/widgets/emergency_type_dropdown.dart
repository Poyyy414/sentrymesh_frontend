import 'package:flutter/material.dart';

class EmergencyTypeDropdown extends StatefulWidget {
  const EmergencyTypeDropdown({this.onChanged, super.key});

  final ValueChanged<String>? onChanged;

  @override
  State<EmergencyTypeDropdown> createState() => _EmergencyTypeDropdownState();
}

class _EmergencyTypeDropdownState extends State<EmergencyTypeDropdown> {
  String _value = 'Medical Emergency';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _value,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.medical_services_rounded,
          color: Color(0xFFE53935),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down),
      items: const [
        DropdownMenuItem(
          value: 'Medical Emergency',
          child: Text('Medical Emergency'),
        ),
        DropdownMenuItem(value: 'Flood Rescue', child: Text('Flood Rescue')),
        DropdownMenuItem(
          value: 'Landslide Rescue',
          child: Text('Landslide Rescue'),
        ),
        DropdownMenuItem(
          value: 'Supply Request',
          child: Text('Supply Request'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _value = value);
          widget.onChanged?.call(value);
        }
      },
    );
  }
}
