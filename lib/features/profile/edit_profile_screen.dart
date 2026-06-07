import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Profile editing form will connect to FastAPI auth endpoints.'),
      ),
    );
  }
}
