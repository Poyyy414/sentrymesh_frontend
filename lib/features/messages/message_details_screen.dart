import 'package:flutter/material.dart';

class MessageDetailsScreen extends StatelessWidget {
  const MessageDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Evacuation route remains open. Follow responder instructions.',
        ),
      ),
    );
  }
}
