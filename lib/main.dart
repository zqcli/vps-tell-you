import 'package:flutter/material.dart';

import 'app.dart';
import 'providers/provider_directory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LedgerApp(directory: ProviderDirectory.remote()));
}
