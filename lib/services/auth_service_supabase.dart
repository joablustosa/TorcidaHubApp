import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';

class AuthServiceSupabase {
  static const String _userEmailKey = 'user_email';
  static const String _rememberMeKey = 'remember_me';

  static final AuthServiceSupabase _instance = AuthServiceSupabase._internal();
  factory AuthServiceSupabase() => _instance;
  AuthServiceSupabase._internal();

  User? _currentUser;
  Profile? _currentProfile;

  User? get currentUser => _currentUser;
  Profile? get currentProfile => _currentProfile;
  bool get isAuthenticated => _currentUser != null;

  String? get userId => _currentUser?.id;
  String? get userEmail => _currentUser?.email;

  Future<void> initialize() async {
    try {
      // Primeiro, verificar sessão existente (similar ao getSession do React)
      final session = SupabaseService.auth.currentSession;
      
      if (session != null) {
        _currentUser = session.user;
        await _loadProfile();
      }

      // Depois, escutar mudanças de autenticação (similar ao onAuthStateChange do React)
      SupabaseService.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        // Ignorar TOKEN_REFRESHED para evitar re-renders desnecessários
        if (event == AuthChangeEvent.tokenRefreshed) {
          return;
        }

        // Só atualizar se o usuário realmente mudou (comparar por ID)
        final prevUserId = _currentUser?.id;
        final newUserId = session?.user.id;

        if (prevUserId == newUserId && prevUserId != null && newUserId != null) {
          return; // Usuário não mudou, não precisa atualizar
        }

        if (event == AuthChangeEvent.signedIn && session != null) {
          _currentUser = session.user;
          _loadProfile();
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          _currentProfile = null;
        } else if (session != null) {
          // Outros eventos que podem ter uma sessão
          _currentUser = session.user;
          _loadProfile();
        } else {
          _currentUser = null;
          _currentProfile = null;
        }
      });
    } catch (e) {
      print('Erro ao inicializar AuthService: $e');
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();

      if (response != null) {
        _currentProfile = Profile.fromJson(Map<String, dynamic>.from(response));
      }
    } catch (e) {
      print('Erro ao carregar perfil: $e');
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      print('AuthService: Tentando fazer login com email: $email');
      
      // Primeiro, tentar fazer login (similar ao signInWithPassword do React)
      final response = await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      print('AuthService: Login realizado. User: ${response.user?.id}');

      if (response.user != null) {
        _currentUser = response.user;
        await _loadProfile();

        // Verificar se email está verificado (similar ao check do React)
        // No React, verifica na tabela profiles o campo email_verified
        // Se o perfil não existir ou email_verified for null/false, verificar diretamente
        bool emailVerified = true; // Default: permitir login
        
        if (_currentProfile != null) {
          // Se email_verified for explicitamente false, bloquear
          if (_currentProfile!.emailVerified == false) {
            emailVerified = false;
          } else if (_currentProfile!.emailVerified == true) {
            emailVerified = true;
          } else {
            // Se for null, verificar diretamente no banco
            try {
              final profileResponse = await SupabaseService.client
                  .from('profiles')
                  .select('email_verified')
                  .eq('id', response.user!.id)
                  .maybeSingle();

              if (profileResponse != null) {
                final verified = profileResponse['email_verified'] as bool?;
                emailVerified = verified ?? true; // Se null, permitir login
              }
            } catch (e) {
              print('Erro ao verificar email_verified: $e');
              // Se não conseguir verificar, permitir login (fallback)
              emailVerified = true;
            }
          }
        } else {
          // Se não conseguir carregar o perfil, verificar diretamente
          try {
            final profileResponse = await SupabaseService.client
                .from('profiles')
                .select('email_verified')
                .eq('id', response.user!.id)
                .maybeSingle();

            if (profileResponse != null) {
              final verified = profileResponse['email_verified'] as bool?;
              emailVerified = verified ?? true; // Se null, permitir login
            }
          } catch (e) {
            print('Erro ao verificar perfil: $e');
            // Se não conseguir verificar, permitir login (fallback)
            emailVerified = true;
          }
        }

        // Só bloquear se email_verified for explicitamente false
        if (emailVerified == false) {
          await signOut();
          throw Exception(
              'Email não verificado. Por favor, verifique seu email antes de fazer login.');
        }
      }

      print('AuthService: Login concluído com sucesso');
      return response;
    } catch (e, stackTrace) {
      print('Erro no login: $e');
      print('Stack trace: $stackTrace');
      
      // Se for erro do Supabase AuthException, manter a mensagem original
      // O erro será tratado na tela de login
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Similar ao signUp do React, inclui full_name nos metadados
      // No Flutter, o emailRedirectTo é configurado no Supabase Dashboard
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (response.user != null) {
        _currentUser = response.user;
        // Não carregar perfil imediatamente pois o email ainda não foi verificado
        // O perfil será criado quando o usuário verificar o email
      }

      return response;
    } catch (e) {
      print('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.auth.signOut();
      _currentUser = null;
      _currentProfile = null;
    } catch (e) {
      print('Erro ao fazer logout: $e');
      rethrow;
    }
  }

  Future<void> saveCredentials(String email, String password, bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString(_userEmailKey, email);
        await prefs.setBool(_rememberMeKey, true);
        // Nota: Não salvar senha por segurança
      } else {
        await prefs.remove(_userEmailKey);
        await prefs.setBool(_rememberMeKey, false);
      }
    } catch (e) {
      print('Erro ao salvar credenciais: $e');
    }
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

      return {
        'email': email,
        'rememberMe': rememberMe.toString(),
      };
    } catch (e) {
      print('Erro ao recuperar credenciais: $e');
      return {
        'email': null,
        'rememberMe': 'false',
      };
    }
  }

  Future<void> clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userEmailKey);
      await prefs.remove(_rememberMeKey);
    } catch (e) {
      print('Erro ao limpar credenciais: $e');
    }
  }

  Future<Profile?> getProfile() async {
    if (_currentUser == null) return null;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();

      if (response != null) {
        _currentProfile = Profile.fromJson(Map<String, dynamic>.from(response));
        return _currentProfile;
      }
      return null;
    } catch (e) {
      print('Erro ao buscar perfil: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? nickname,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (nickname != null) updates['nickname'] = nickname;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('id', _currentUser!.id);

      await _loadProfile();
    } catch (e) {
      print('Erro ao atualizar perfil: $e');
      rethrow;
    }
  }
}

