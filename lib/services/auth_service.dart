import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _rememberMeKey = 'remember_me';
  static const String _tenantIdKey = 'tenant_id';
  static const String _idEnterpriseKey = 'id_enterprise';
  static const String _usuarioSessaoKey = 'usuario_sessao';
  static const String _userStatusKey = 'user_status';
  static const String _userTypeKey = 'user_type';
  static const String _baseUrl =
      'https://festaproapi-b3gtbuaegjbucyap.canadacentral-01.azurewebsites.net';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    print(
        '🏭 Factory AuthService() chamado, retornando instância: ${_instance.hashCode}');
    return _instance;
  }
  AuthService._internal() {
    print(
        '🔧 Construtor interno AuthService._internal() chamado, hash: ${hashCode}');
  }

  String? _token;
  int? _userId;
  DateTime? _tokenExpiry;
  int? _tenantId;
  int? _idEnterprise;
  int? _usuarioSessao;
  int? _userStatus;
  int? _userType;

  VoidCallback? _onTokenInvalid;

  String? get token => _token;
  int? get userId => _userId;
  int? get tenantId => _tenantId;
  int? get idEnterprise => _idEnterprise;
  int? get usuarioSessao => _usuarioSessao;
  int? get userStatus => _userStatus;
  int? get userType => _userType;
  bool get isAuthenticated => _token != null && !_isTokenExpired();

  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  bool get isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  DateTime _parseDateTime(String? dataString) {
    try {
      if (dataString == null || dataString.isEmpty) {
        return DateTime.now();
      }
      // Converter formato "2025-12-03 18:45:25" para "2025-12-03T18:45:25"
      final normalizedDate = dataString.replaceAll(' ', 'T');
      return DateTime.parse(normalizedDate);
    } catch (e) {
      print('Erro ao fazer parse da data: $dataString - $e');
      return DateTime.now();
    }
  }

  Future<void> initialize() async {
    try {
      print('AuthService: Iniciando inicialização...');
      await _loadFromStorage();
      print(
          'AuthService: Dados carregados - Token: ${_token != null ? "Presente" : "Ausente"}, UserId: $_userId, Expiry: $_tokenExpiry');
      print('AuthService: Autenticado: $isAuthenticated');
    } catch (e) {
      print('❌ Erro ao inicializar AuthService: $e');
      _token = null;
      _userId = null;
      _tokenExpiry = null;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _userId = prefs.getInt(_userIdKey);
      _tenantId = prefs.getInt(_tenantIdKey);
      _idEnterprise = prefs.getInt(_idEnterpriseKey);
      _usuarioSessao = prefs.getInt(_usuarioSessaoKey);
      _userStatus = prefs.getInt(_userStatusKey);
      _userType = prefs.getInt(_userTypeKey);

      final expiryString = prefs.getString(_tokenExpiryKey);
      if (expiryString != null) {
        _tokenExpiry = _parseDateTime(expiryString);
      }
    } catch (e) {
      print('Erro ao carregar dados de autenticação: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
      }
      if (_userId != null) {
        await prefs.setInt(_userIdKey, _userId!);
      }
      if (_tokenExpiry != null) {
        await prefs.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String());
      }
      if (_tenantId != null) {
        await prefs.setInt(_tenantIdKey, _tenantId!);
      }
      if (_idEnterprise != null) {
        await prefs.setInt(_idEnterpriseKey, _idEnterprise!);
      }
      if (_usuarioSessao != null) {
        await prefs.setInt(_usuarioSessaoKey, _usuarioSessao!);
      }
      if (_userStatus != null) {
        await prefs.setInt(_userStatusKey, _userStatus!);
      }
      if (_userType != null) {
        await prefs.setInt(_userTypeKey, _userType!);
      }
    } catch (e) {
      print('Erro ao salvar dados de autenticação: $e');
    }
  }

  Future<LoginResponse> login(String email, String senha,
      {bool saveCredentials = false}) async {
    try {
      final loginRequest = LoginRequest(
        usuarioLogin: email,
        chaveDeAcesso: senha,
      );

      print('🌐 Tentando conectar em: $_baseUrl/api/login/v1');
      print('📤 Dados do login: ${loginRequest.toJson()}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login/v1'),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: json.encode(loginRequest.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout ao conectar com o servidor. Verifique sua conexão com a internet.');
        },
      );

      print('Status da resposta de login: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        // A resposta agora é um objeto JSON direto
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        
        // Criar LoginResponse a partir do JSON
        final loginResponse = LoginResponse.fromJson(responseData);
        
        if (loginResponse.accessToken.isNotEmpty && loginResponse.autenticated) {
          // Decodificar JWT para extrair informações
          await _decodeAndSaveTokenData(loginResponse.accessToken);
          
          await _setAuthData(loginResponse);
          
          // Buscar userType após login bem-sucedido
          await _fetchUserType();
          
          // Salvar credenciais se solicitado
          if (saveCredentials) {
            await this.saveCredentials(email, senha, true);
          }

          return loginResponse;
        } else {
          return LoginResponse(
            autenticated: false,
            created: '',
            expiration: '',
            accessToken: '',
            message: loginResponse.message.isNotEmpty 
                ? loginResponse.message 
                : 'Token não encontrado na resposta',
          );
        }
      } else {
        print(
            'Erro na requisição de login: ${response.statusCode} - ${response.body}');
        return LoginResponse(
          autenticated: false,
          created: '',
          expiration: '',
          accessToken: '',
          message: 'Erro na requisição: ${response.statusCode}',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ Erro de conexão no login: $e');
      String errorMessage = 'Erro de conexão';
      if (e.message.contains('Failed host lookup') || e.message.contains('No address associated with hostname')) {
        errorMessage = 'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e tente novamente.';
      } else if (e.message.contains('Timeout')) {
        errorMessage = 'Tempo de conexão esgotado. Verifique sua conexão com a internet.';
      } else {
        errorMessage = 'Erro de conexão: ${e.message}';
      }
      return LoginResponse(
        autenticated: false,
        created: '',
        expiration: '',
        accessToken: '',
        message: errorMessage,
      );
    } catch (e) {
      print('❌ Exceção no login: $e');
      String errorMessage = 'Erro ao fazer login';
      if (e.toString().contains('Failed host lookup') || e.toString().contains('No address associated with hostname')) {
        errorMessage = 'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e tente novamente.';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Tempo de conexão esgotado. Verifique sua conexão com a internet.';
      } else {
        errorMessage = 'Erro ao fazer login: ${e.toString()}';
      }
      return LoginResponse(
        autenticated: false,
        created: '',
        expiration: '',
        accessToken: '',
        message: errorMessage,
      );
    }
  }

  // Decodificar JWT e extrair dados
  Future<void> _decodeAndSaveTokenData(String token) async {
    try {
      // JWT tem 3 partes separadas por ponto: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        print('⚠️ Token JWT inválido - não tem 3 partes');
        return;
      }

      // Decodificar o payload (segunda parte)
      String payload = parts[1];
      
      // Adicionar padding se necessário
      switch (payload.length % 4) {
        case 1:
          payload += '===';
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      // Decodificar base64 (URL-safe)
      // Substituir caracteres URL-safe por caracteres padrão
      final normalizedPayload = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decodedBytes = base64Decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);
      final payloadJson = json.decode(decodedString);

      print('📋 Payload do JWT decodificado: $payloadJson');

      // Extrair dados do payload
      // O formato pode variar, mas geralmente está em 'aud' como array
      if (payloadJson['aud'] != null && payloadJson['aud'] is List) {
        final audList = payloadJson['aud'] as List;
        if (audList.isNotEmpty) {
          final userAud = json.decode(audList[0] as String);
          
          _tenantId = int.tryParse(userAud['tenant_id']?.toString() ?? '0') ?? 0;
          _idEnterprise = int.tryParse(userAud['id_enterprise']?.toString() ?? '0') ?? 0;
          _usuarioSessao = int.tryParse(userAud['Id']?.toString() ?? '0') ?? 0;
          _userStatus = int.tryParse(userAud['UserStatus']?.toString() ?? '0') ?? 0;
          _userId = _usuarioSessao;

          print('✅ Dados extraídos do token:');
          print('   tenant_id: $_tenantId');
          print('   id_enterprise: $_idEnterprise');
          print('   usuarioSessao (Id): $_usuarioSessao');
          print('   userStatus: $_userStatus');
        }
      } else {
        // Tentar extrair diretamente do payload
        _tenantId = int.tryParse(payloadJson['tenant_id']?.toString() ?? '0') ?? 0;
        _idEnterprise = int.tryParse(payloadJson['id_enterprise']?.toString() ?? '0') ?? 0;
        _usuarioSessao = int.tryParse(payloadJson['Id']?.toString() ?? payloadJson['id']?.toString() ?? '0') ?? 0;
        _userStatus = int.tryParse(payloadJson['UserStatus']?.toString() ?? '0') ?? 0;
        _userId = _usuarioSessao;
      }
    } catch (e) {
      print('❌ Erro ao decodificar JWT: $e');
      // Em caso de erro, usar valores padrão
      _userId = _usuarioSessao ?? 0;
    }
  }

  Future<void> _setAuthData(LoginResponse response) async {
    _token = response.token;

    // userId já foi definido em _decodeAndSaveTokenData
    if (_userId == null) {
      _userId = _usuarioSessao ?? 0;
    }

    print('Token definido: ${_token != null ? "Presente" : "Ausente"}');
    print('UserId definido: $_userId');

    try {
      _tokenExpiry = _parseDateTime(response.expiraEm);
      print('Token expira em: $_tokenExpiry');
    } catch (e) {
      _tokenExpiry = DateTime.now().add(const Duration(hours: 24));
      print('Token expira em (padrão): $_tokenExpiry');
    }

    await _saveToStorage();
    print('Dados de autenticação salvos no storage');
  }

  // Buscar userType do usuário via API
  Future<void> _fetchUserType() async {
    try {
      if (_userId == null) {
        print('⚠️ UserId não disponível para buscar userType');
        return;
      }

      print('🔍 Buscando userType para userId: $_userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/Users/v1/$_userId'),
        headers: getAuthHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout ao buscar userType');
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;
        _userType = userData['userType'] != null 
            ? int.tryParse(userData['userType'].toString()) 
            : null;
        
        print('✅ UserType obtido: $_userType');
        await _saveToStorage();
      } else {
        print('⚠️ Erro ao buscar userType: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao buscar userType: $e');
      // Não falha o login se não conseguir buscar userType
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _tokenExpiry = null;
    _tenantId = null;
    _idEnterprise = null;
    _usuarioSessao = null;
    _userStatus = null;
    _userType = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.remove(_tenantIdKey);
      await prefs.remove(_idEnterpriseKey);
      await prefs.remove(_usuarioSessaoKey);
      await prefs.remove(_userStatusKey);
      await prefs.remove(_userTypeKey);

      // Verificar se deve manter credenciais salvas
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      if (!rememberMe) {
        // Se não está marcado para lembrar, limpar credenciais
        await prefs.remove(_savedEmailKey);
        await prefs.remove(_savedPasswordKey);
        await prefs.remove(_rememberMeKey);
      }
    } catch (e) {
      print('Erro ao limpar dados de autenticação: $e');
    }
  }

  // Salvar credenciais do usuário
  Future<void> saveCredentials(
      String email, String password, bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString(_savedEmailKey, email);
        await prefs.setString(_savedPasswordKey, password);
        await prefs.setBool(_rememberMeKey, true);
        print('✅ Credenciais salvas com sucesso');
      } else {
        // Se não quer lembrar, remover credenciais salvas
        await prefs.remove(_savedEmailKey);
        await prefs.remove(_savedPasswordKey);
        await prefs.setBool(_rememberMeKey, false);
        print('✅ Credenciais removidas');
      }
    } catch (e) {
      print('❌ Erro ao salvar credenciais: $e');
    }
  }

  // Recuperar credenciais salvas
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_savedEmailKey);
      final password = prefs.getString(_savedPasswordKey);
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

      if (rememberMe && email != null && password != null) {
        print('✅ Credenciais recuperadas');
        return {
          'email': email,
          'password': password,
          'rememberMe': rememberMe.toString(),
        };
      } else {
        print('ℹ️ Nenhuma credencial salva encontrada');
        return {
          'email': null,
          'password': null,
          'rememberMe': 'false',
        };
      }
    } catch (e) {
      print('❌ Erro ao recuperar credenciais: $e');
      return {
        'email': null,
        'password': null,
        'rememberMe': 'false',
      };
    }
  }

  // Limpar credenciais salvas
  Future<void> clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedEmailKey);
      await prefs.remove(_savedPasswordKey);
      await prefs.remove(_rememberMeKey);
      print('✅ Credenciais salvas removidas');
    } catch (e) {
      print('❌ Erro ao limpar credenciais: $e');
    }
  }

  Map<String, String> getAuthHeaders() {
    print('🔐 === VERIFICANDO AUTENTICAÇÃO ===');
    print(
        'Token: ${_token != null ? "Presente (${_token!.substring(0, 20)}...)" : "Ausente"}');
    print('UserId: $_userId');
    print('Token expira em: $_tokenExpiry');
    print('Is authenticated: $isAuthenticated');
    print('Token expirado: ${_isTokenExpired()}');

    if (!isAuthenticated) {
      print('❌ Usuário não autenticado - lançando exceção');
      throw Exception('Usuário não autenticado');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    print('✅ Headers retornados: $headers');
    print('=== VERIFICAÇÃO DE AUTENTICAÇÃO CONCLUÍDA ===');
    return headers;
  }

  bool get needsTokenRefresh {
    if (_tokenExpiry == null) return false;

    final oneHourBefore = _tokenExpiry!.subtract(const Duration(hours: 1));
    return DateTime.now().isAfter(oneHourBefore);
  }

  void setOnTokenInvalidCallback(VoidCallback callback) {
    _onTokenInvalid = callback;
  }

  void _executeTokenInvalidCallback() {
    if (_onTokenInvalid != null) {
      print('🔐 Executando callback de token inválido');
      _onTokenInvalid!();
    } else {
      print('⚠️ Callback de token inválido não configurado');
    }
  }

  Future<void> logoutDueToInvalidToken() async {
    print('🔐 Token inválido detectado - fazendo logout automático');
    await logout();
    _executeTokenInvalidCallback();
  }
}
