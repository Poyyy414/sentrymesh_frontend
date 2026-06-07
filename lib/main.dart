import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await configureDependencies();

  runApp(SentryMeshApp(dependencies: dependencies));
}
