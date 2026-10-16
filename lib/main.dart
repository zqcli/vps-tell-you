import 'package:flutter/material.dart';

import 'app.dart';
import 'connections/terminal_font.dart';
import 'providers/provider_directory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Listed under Settings / About / Open-Source Components.
  registerTerminalFontLicense();
  runApp(LedgerApp(directory: ProviderDirectory.remote()));
}
