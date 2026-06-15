import 'package:flutter/material.dart';

import '../../data/models/alert_model.dart';

class MessageDetailsScreen extends StatelessWidget {
  const MessageDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alert = ModalRoute.of(context)?.settings.arguments as AlertModel?;

    return Scaffold(
      appBar: AppBar(title: Text(alert?.title ?? 'Message')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert != null) ...[
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.location,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                alert.message.isNotEmpty
                    ? alert.message
                    : 'No additional details provided.',
              ),
            ] else
              const Text(
                'No message content available.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
