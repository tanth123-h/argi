import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xkuhehyjvyxpnfjmpkyg.supabase.co',
    // Use the legacy anon key (long JWT starting with eyJ...) from:
    // Supabase Dashboard → Settings → API → Project API keys → anon / public
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhrdWhlaHlqdnl4cG5mam1wa3lnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MTkzMDMsImV4cCI6MjEwMTk5NTMwM30.73QMjpI1yz65dUTsbwP-iVsjUDXue7XBYxTwhiuJxf4',
  );

  runApp(const ProviderScope(child: VerdantApp()));
}
