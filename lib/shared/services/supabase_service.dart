import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ighutbzdcqvhjwqvsrzg.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnaHV0YnpkY3F2aGp3cXZzcnpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3Njc5MjYsImV4cCI6MjA5MjM0MzkyNn0.hW22b1L9kKnIXoQm9mnoPzsjFwSX-HY_an2qvbt5sCw';

SupabaseClient get supabase => Supabase.instance.client;
