import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // IMPORTANTE: Configure a chave anon do seu projeto Supabase
  // Você pode encontrar essa chave no painel do Supabase em Settings > API > anon/public key
  static const String supabaseUrl = 'https://beseykjqpzymgzwkzoqj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlc2V5a2pxcHp5bWd6d2t6b3FqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNjczMTcsImV4cCI6MjA4MzY0MzMxN30.mKkemJluUbm131pbb9mcd0BVdN0XniOemKHw25YxCtM'; // Substitua pela chave anon do seu projeto

  static SupabaseClient? _client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase não foi inicializado. Chame SupabaseService.initialize() primeiro.');
    }
    return _client!;
  }

  static GoTrueClient get auth => client.auth;
  static RealtimeClient get realtime => client.realtime;
  // Storage access via client.storage when needed
}

