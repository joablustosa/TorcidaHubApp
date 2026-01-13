import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';
import 'auth_service.dart';

// Se usar intl: import 'package:intl/intl.dart';
String fmtLocal(DateTime dt, {bool withFraction = false}) {
  final local = dt.toLocal();
  if (!withFraction) {
    // yyyy-MM-ddTHH:mm:ss
    // return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(local);
    // Sem intl:
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}T'
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
  // Mantém frações (quando existirem) mas sem 'Z'
  final s = local.toIso8601String(); // já vem sem Z por ser local
  return s;
}

String? fmtLocalOrNull(dynamic v, {bool withFraction = false}) {
  if (v == null) return null;
  if (v is DateTime) return fmtLocal(v, withFraction: withFraction);
  if (v is String && v.trim().isNotEmpty) {
    return fmtLocal(DateTime.parse(v), withFraction: withFraction);
  }
  return null;
}

class ApiService {
  static const String _baseUrl =
      'https://festaproapi-b3gtbuaegjbucyap.canadacentral-01.azurewebsites.net';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;

  // Inicializar o serviço
  Future<void> initialize() async {
    print('🚀 === INICIALIZANDO APISERVICE ===');
    if (!_isInitialized) {
      print('📡 Inicializando AuthService...');
      await _authService.initialize();
      print('✅ AuthService inicializado com sucesso');
      _isInitialized = true;
      print('✅ ApiService inicializado com sucesso');
    } else {
      print('ℹ️ ApiService já está inicializado');
    }
    print('=== INICIALIZAÇÃO CONCLUÍDA ===');
  }

  // Verificar se está inicializado
  Future<void> _ensureInitialized() async {
    print('🔧 Verificando inicialização do ApiService...');
    if (!_isInitialized) {
      print('⚠️ Não está inicializado, inicializando...');
      await initialize();
    } else {
      print('✅ Já está inicializado');
    }
  }

  // Verificar se a resposta indica token inválido
  Future<void> _handleResponseStatus(
      int statusCode, String responseBody) async {
    if (statusCode == 401) {
      print(
          '❌ Token inválido ou expirado (401) - executando logout automático');
      await _authService.logoutDueToInvalidToken();
      throw Exception(
          'Token inválido ou expirado - usuário redirecionado para login');
    }
  }

  // GET genérico - SEMPRE autenticado
  Future<dynamic> get(String endpoint) async {
    try {
      print('🔍 === REQUISIÇÃO GET ===');
      print('Endpoint: $endpoint');
      print('Verificando inicialização...');

      await _ensureInitialized();
      print('✅ Serviço inicializado, obtendo headers...');

      final headers = _authService.getAuthHeaders();
      print('✅ Headers obtidos com sucesso');
      print('Headers: $headers');

      final url = '$_baseUrl$endpoint';
      print('🌐 URL completa: $url');

      print('📤 Enviando requisição GET...');
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📥 Resposta recebida:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');
      print('  Headers: ${response.headers}');

      // Verificar se a resposta indica token inválido
      await _handleResponseStatus(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('✅ Resposta decodificada com sucesso');
        print('  Tipo: ${decoded.runtimeType}');
        print('  Conteúdo: $decoded');
        return decoded;
      } else {
        print('❌ Erro na requisição GET: ${response.statusCode}');
        print('  Body: ${response.body}');
        throw Exception('Erro na requisição: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exceção na requisição GET: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Erro na requisição: $e');
    }
  }

  // POST genérico - pode ser autenticado ou não
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data,
      {bool requireAuth = true}) async {
    try {
      print('📝 === REQUISIÇÃO POST ===');
      print('Endpoint: $endpoint');
      print('Require Auth: $requireAuth');

      Map<String, String> headers;

      if (requireAuth) {
        await _ensureInitialized();
        print('✅ Serviço inicializado, obtendo headers...');
        headers = _authService.getAuthHeaders();
        print('✅ Headers obtidos com sucesso');
      } else {
        // Para cadastro, não precisa de autenticação
        headers = {
          'Content-Type': 'application/json',
          'accept': '*/*',
        };
        print('✅ Usando headers sem autenticação');
      }

      print('Headers: $headers');

      final url = '$_baseUrl$endpoint';
      print('🌐 URL completa: $url');
      print('📤 Dados para envio: $data');

      print('📤 Enviando requisição POST...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(data),
      );

      print('📥 Resposta recebida:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');
      print('  Headers: ${response.headers}');

      // Verificar se a resposta indica token inválido (apenas se requer autenticação)
      if (requireAuth) {
        await _handleResponseStatus(response.statusCode, response.body);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        print('✅ Resposta decodificada com sucesso');
        print('  Tipo: ${decoded.runtimeType}');
        print('  Conteúdo: $decoded');
        return decoded;
      } else {
        print('❌ Erro na requisição POST: ${response.statusCode}');
        print('  Body: ${response.body}');
        throw Exception('Erro na requisição: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exceção na requisição POST: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Erro na requisição: $e');
    }
  }

  // PATCH genérico - SEMPRE autenticado
  Future<Map<String, dynamic>> patch(
      String endpoint, Map<String, dynamic> data) async {
    try {
      await _ensureInitialized();
      final headers = _authService.getAuthHeaders();

      print('Fazendo PATCH para: $_baseUrl$endpoint');
      print('Headers: $headers');
      print('Dados: $data');

      final response = await http.patch(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      print('Resposta PATCH: ${response.statusCode} - ${response.body}');

      // Verificar se a resposta indica token inválido
      await _handleResponseStatus(response.statusCode, response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print(
            'Erro na requisição PATCH: ${response.statusCode} - ${response.body}');
        throw Exception('Erro na requisição: ${response.statusCode}');
      }
    } catch (e) {
      print('Exceção na requisição PATCH: $e');
      throw Exception('Erro na requisição: $e');
    }
  }

  Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    try {
      await _ensureInitialized();

      final headers = {
        ..._authService.getAuthHeaders(),
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      print('Fazendo PUT para: $_baseUrl$endpoint');
      print('Headers: $headers');
      print('Dados: ${json.encode(data)}');

      final response = await http.put(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      print('Resposta PUT: ${response.statusCode} - ${response.body}');

      await _handleResponseStatus(response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return (response.body.isNotEmpty)
            ? Map<String, dynamic>.from(json.decode(response.body))
            : <String, dynamic>{};
      }

      if (response.statusCode == 204) {
        // Sem corpo – considere retornar o que enviou ou um map vazio
        return <String, dynamic>{};
      }

      throw Exception(
          'Erro na requisição: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Exceção na requisição PUT: $e');
      throw Exception('Erro na requisição: $e');
    }
  }

  // DELETE genérico - SEMPRE autenticado
  Future<bool> delete(String endpoint) async {
    try {
      await _ensureInitialized();
      final headers = _authService.getAuthHeaders();

      print('Fazendo DELETE para: $_baseUrl$endpoint');
      print('Headers: $headers');

      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      );

      print('Resposta DELETE: ${response.statusCode} - ${response.body}');

      // Verificar se a resposta indica token inválido
      await _handleResponseStatus(response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print(
            'Erro na requisição DELETE: ${response.statusCode} - ${response.body}');
        throw Exception('Erro na requisição: ${response.statusCode}');
      }
    } catch (e) {
      print('Exceção na requisição DELETE: $e');
      throw Exception('Erro na requisição: $e');
    }
  }

  // LIMPEZAS - SEMPRE autenticadas
  Future<List<EventoApi>> getEventos() async {
    try {
      print('Buscando eventos da API...');
      final response = await get('/api/Eventos/v1');
      print('Resposta da API: $response (tipo: ${response.runtimeType})');

      List<dynamic> eventos;

      if (response is List) {
        // A API retorna uma lista diretamente
        eventos = response;
        print('Resposta é uma lista direta com ${eventos.length} eventos');
      } else if (response is Map && response['data'] != null) {
        // A API retorna um objeto com chave 'data'
        eventos = response['data'];
        print(
            'Resposta é um objeto com chave data contendo ${eventos.length} eventos');
      } else {
        // Caso inesperado
        print('Formato de resposta inesperado: $response');
        eventos = [];
      }

      print('Lista de eventos encontrada: ${eventos.length}');

      if (eventos.isEmpty) {
        print('Nenhuma evento encontrada');
        return [];
      }

      return eventos
          .map((json) => EventoApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('Erro ao buscar eventos: $e');
      throw Exception('Erro ao buscar eventos: $e');
    }
  }

  // Buscar evento por ID
  Future<EventoApi> getEventoById(int id) async {
    try {
      print('Buscando evento por ID: $id');
      final response = await get('/api/Eventos/v1/$id');
      print('Evento encontrada: $response (tipo: ${response.runtimeType})');

      if (response is Map) {
        return EventoApi.fromJson(Map<String, dynamic>.from(response));
      } else {
        throw Exception('Formato de resposta inesperado para evento por ID');
      }
    } catch (e) {
      print('Erro ao buscar evento por ID: $e');
      throw Exception('Erro ao buscar evento por ID: $e');
    }
  }

  // Buscar eventos por data específica
  Future<List<EventoApi>> getEventosPorData(DateTime data) async {
    try {
      print(
          'Buscando eventos para a data: ${data.toIso8601String().split('T')[0]}');

      // Formatar a data no formato YYYY-MM-DD
      final dataFormatada =
          '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

      final response = await get('/api/Eventos/v1/PorData?data=$dataFormatada');
      print(
          'Resposta da API para data $dataFormatada: $response (tipo: ${response.runtimeType})');

      List<dynamic> eventos;

      if (response is List) {
        // A API retorna uma lista diretamente
        eventos = response;
        print('Resposta é uma lista direta com ${eventos.length} eventos');
      } else if (response is Map && response['data'] != null) {
        // A API retorna um objeto com chave 'data'
        eventos = response['data'];
        print(
            'Resposta é um objeto com chave data contendo ${eventos.length} eventos');
      } else {
        // Caso inesperado
        print('Formato de resposta inesperado: $response');
        eventos = [];
      }

      print(
          'Lista de eventos encontrada para a data $dataFormatada: ${eventos.length}');

      if (eventos.isEmpty) {
        print('Nenhuma evento encontrada para a data $dataFormatada');
        return [];
      }

      return eventos
          .map((json) => EventoApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('Erro ao buscar eventos por data: $e');
      throw Exception('Erro ao buscar eventos por data: $e');
    }
  }

  Future<EventoApi> createEvento(EventoApi evento) async {
    try {
      print('Criando nova evento...');

      // Adicionar dados padrão conforme esperado pela API
      final eventoCompleta = EventoApi(
        id: 0,
        data_hora_criacao: DateTime.now().toIso8601String(),
        id_usuario_criacao: _authService.userId ?? 0,
        deletado: false,
        data_hora_deletado: null,
        id_usuario: _authService.userId ?? 0,
        id_cliente: evento.id_cliente,
        valor: evento.valor,
        data_hora_evento:
            evento.data_hora_evento ?? DateTime.now().toIso8601String(),
        confirmado: false,
        prioridade: 0,
        data_hora_confirmado: null,
        forma_de_pagamento: null,
      );

      print('Evento completa para envio: ${eventoCompleta.toJson()}');
      final response = await post('/api/Eventos/v1', eventoCompleta.toJson());
      print('Evento criada: $response (tipo: ${response.runtimeType})');

      return EventoApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao criar evento: $e');
      throw Exception('Erro ao criar evento: $e');
    }
  }

  Future<EventoApi> updateEvento(int id, EventoApi evento) async {
    try {
      print('🔄 === ATUALIZANDO LIMPEZA ===');
      print('ID: $id');
      print('Dados para atualização: ${evento.toJson()}');

      // Garantir que todos os campos obrigatórios estejam preenchidos
      final dadosCompletos = {
        'id': evento.id, // certifique-se que == id
        'data_hora_criacao': fmtLocalOrNull(evento.data_hora_criacao) ??
            fmtLocal(DateTime.now()),
        'id_usuario_criacao': evento.id_usuario_criacao,
        'deletado': evento.deletado,
        'data_hora_deletado': fmtLocalOrNull(evento.data_hora_deletado),
        'id_usuario': evento.id_usuario,
        'id_cliente': evento.id_cliente,
        'valor': evento.valor,
        'data_hora_evento':
            fmtLocalOrNull(evento.data_hora_evento) ?? fmtLocal(DateTime.now()),
        'confirmado': evento.confirmado,
        'prioridade': evento.prioridade,
        'data_hora_confirmado':
            fmtLocalOrNull(evento.data_hora_confirmado, withFraction: true),
        'forma_de_pagamento':
            evento.forma_de_pagamento, // se API não aceita null, garanta string
      };

      print('📤 Dados completos para envio: $dadosCompletos');

      final response = await put('/api/Eventos/v1', dadosCompletos);
      print(
          '✅ Evento atualizada via PUT: $response (tipo: ${response.runtimeType})');

      return EventoApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao atualizar evento: $e');
      throw Exception('Erro ao atualizar evento: $e');
    }
  }

  Future<bool> deleteEvento(int id) async {
    try {
      print('Deletando evento ID: $id');
      return await delete('/api/Eventos/v1/$id');
    } catch (e) {
      print('Erro ao deletar evento: $e');
      throw Exception('Erro ao deletar evento: $e');
    }
  }

  // CLIENTES - Removidos (agora usar getUsers com userType=2)

  // Teste de conectividade com a API
  Future<bool> testConnection() async {
    try {
      print('🧪 === TESTE DE CONECTIVIDADE ===');
      print('URL base: $_baseUrl');

      // Fazer uma requisição simples para verificar se a API está respondendo
      final url = '$_baseUrl/api/Users/v1';
      print('📡 Testando endpoint: $url');

      final response = await http.get(Uri.parse(url));
      print('📥 Resposta recebida: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 401) {
        print('✅ API está respondendo (status: ${response.statusCode})');
        return true;
      } else {
        print(
            '❌ API não está respondendo corretamente (status: ${response.statusCode})');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao testar conectividade: $e');
      return false;
    }
  }

  // USUÁRIOS
  Future<UsuarioApi> createUsuario(UsuarioApi usuario) async {
    try {
      print('📝 === CRIANDO NOVO USUÁRIO ===');
      print('Dados recebidos: ${usuario.toJson()}');

      // Preparar dados completos para envio
      final usuarioCompleto = UsuarioApi(
        id: 0,
        nome: usuario.nome,
        email: usuario.email,
        telefone: usuario.telefone,
        senha: usuario.senha,
        data_hora_criacao: DateTime.now().toIso8601String(),
        id_usuario_criacao: 0,
        deletado: false,
        data_hora_deletado: null,
      );

      print('📤 Usuário completo para envio: ${usuarioCompleto.toJson()}');

      // Fazer POST sem autenticação (cadastro público)
      final response = await post('/api/Users/v1', usuarioCompleto.toJson(),
          requireAuth: false);
      print('📥 Resposta da API: $response');

      final usuarioCriado =
          UsuarioApi.fromJson(Map<String, dynamic>.from(response));
      print(
          '✅ Usuário criado: ID=${usuarioCriado.id}, Nome=${usuarioCriado.nome}');
      return usuarioCriado;
    } catch (e) {
      print('❌ Erro ao criar usuário: $e');
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  // USUÁRIOS - SEMPRE autenticados
  Future<UsuarioApi> getUsuario(int id) async {
    try {
      print('=== BUSCANDO DADOS DO USUÁRIO ===');
      print('Endpoint: /api/Usuarios/v1/$id');

      final response = await get('/api/Users/v1/$id');
      print('Resposta da API: $response (tipo: ${response.runtimeType})');

      if (response is Map) {
        return UsuarioApi.fromJson(Map<String, dynamic>.from(response));
      } else {
        throw Exception('Formato de resposta inesperado para usuário');
      }
    } catch (e) {
      print('❌ Erro ao buscar usuário: $e');
      throw Exception('Erro ao buscar usuário: $e');
    }
  }

  Future<UsuarioApi> updateUsuario(int id, UsuarioApi usuario) async {
    try {
      final dadosCompletos = {
        'id': usuario.id,
        'data_hora_criacao': usuario.data_hora_criacao,
        'deletado': usuario.deletado,
        'id_usuario_criacao': usuario.id_usuario_criacao,
        'data_hora_deletado': usuario.data_hora_deletado,
        'nome': usuario.nome,
        'email': usuario.email,
        'telefone': usuario.telefone,
        'senha': usuario.senha,
      };

      // Remover campos que são null para não enviar strings vazias
      dadosCompletos.removeWhere((key, value) => value == null);

      final response = await put('/api/Users/v1/$id', dadosCompletos);

      return UsuarioApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Erro ao atualizar usuário: $e');
    }
  }

  // TRANSACTIONS - Movimentações agora são Transactions
  Future<List<TransactionApi>> getTransactions({int? idEvent}) async {
    try {
      print('=== BUSCANDO TRANSAÇÕES ===');
      String endpoint = '/api/Transactions/v1';
      if (idEvent != null) {
        endpoint += '?id_event=$idEvent';
      }

      print('Endpoint: $endpoint');
      final response = await get(endpoint);
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> transactions;
      if (response is List) {
        transactions = response;
      } else if (response is Map && response['data'] != null) {
        transactions = response['data'];
      } else {
        transactions = [];
      }

      print('📊 Transações encontradas: ${transactions.length}');

      return transactions
          .map((json) =>
              TransactionApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar transações: $e');
      throw Exception('Erro ao buscar transações: $e');
    }
  }

  Future<TransactionApi> createTransaction(TransactionApi transaction) async {
    try {
      print('📝 === CRIANDO NOVA TRANSAÇÃO ===');
      print('Dados recebidos: ${transaction.toJson()}');

      // Obter dados do usuário logado
      final tenantId = _authService.tenantId ?? 0;
      final idEnterprise = _authService.idEnterprise ?? 0;
      final idUserCreate =
          _authService.usuarioSessao ?? _authService.userId ?? 0;

      final transactionData = transaction.toJson();
      transactionData['tenant_id'] = tenantId;
      transactionData['id_enterprise'] = idEnterprise;
      transactionData['id_user_created'] = idUserCreate;
      transactionData['datetime_created'] = DateTime.now().toIso8601String();
      transactionData['status'] = transactionData['status'] ?? 0;
      transactionData['id_user_status'] = idUserCreate;
      transactionData['datetime_status'] = DateTime.now().toIso8601String();

      print('📤 Transação completa para envio: $transactionData');
      final response = await post('/api/Transactions/v1', transactionData);
      print('📥 Resposta da API: $response');

      return TransactionApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao criar transação: $e');
      throw Exception('Erro ao criar transação: $e');
    }
  }

  Future<TransactionApi> updateTransaction(
      int id, TransactionApi transaction) async {
    try {
      print('🔄 === ATUALIZANDO TRANSAÇÃO ===');

      final transactionData = transaction.toJson();
      transactionData['id'] = id;

      // Manter dados do usuário logado
      if (transactionData['tenant_id'] == null ||
          transactionData['tenant_id'] == 0) {
        transactionData['tenant_id'] = _authService.tenantId ?? 0;
      }
      if (transactionData['id_enterprise'] == null ||
          transactionData['id_enterprise'] == 0) {
        transactionData['id_enterprise'] = _authService.idEnterprise ?? 0;
      }
      if (transactionData['id_user_created'] == null ||
          transactionData['id_user_created'] == 0) {
        transactionData['id_user_created'] =
            _authService.usuarioSessao ?? _authService.userId ?? 0;
      }

      print('📤 Dados para atualização: $transactionData');
      final response = await put('/api/Transactions/v1/$id', transactionData);
      print('✅ Transação atualizada: $response');

      return TransactionApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao atualizar transação: $e');
      throw Exception('Erro ao atualizar transação: $e');
    }
  }

  // EVENTS - SEMPRE autenticados
  Future<List<EventApi>> getEvents() async {
    try {
      print('=== BUSCANDO EVENTOS ===');
      print('Endpoint: /api/Events/v1');

      final response = await get('/api/Events/v1');
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> events;
      if (response is List) {
        events = response;
      } else if (response is Map && response['data'] != null) {
        events = response['data'];
      } else {
        events = [];
      }

      print('📊 Eventos encontrados: ${events.length}');

      return events
          .map((json) => EventApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar eventos: $e');
      throw Exception('Erro ao buscar eventos: $e');
    }
  }

  Future<EventApi> getEventById(int id) async {
    try {
      print('Buscando evento por ID: $id');
      final response = await get('/api/Events/v1/$id');
      print('Evento encontrado: $response (tipo: ${response.runtimeType})');

      if (response is Map) {
        return EventApi.fromJson(Map<String, dynamic>.from(response));
      } else {
        throw Exception('Formato de resposta inesperado para evento por ID');
      }
    } catch (e) {
      print('Erro ao buscar evento por ID: $e');
      throw Exception('Erro ao buscar evento por ID: $e');
    }
  }

  Future<EventApi> createEvent(EventApi event) async {
    try {
      print('📝 === CRIANDO NOVO EVENTO ===');

      // Obter dados do usuário logado
      final tenantId = _authService.tenantId ?? 0;
      final idEnterprise = _authService.idEnterprise ?? 0;
      final idUserCreate =
          _authService.usuarioSessao ?? _authService.userId ?? 0;

      final eventData = event.toJson();
      eventData['tenant_id'] = tenantId;
      eventData['id_enterprise'] = idEnterprise;
      eventData['id_user_create'] = idUserCreate;
      eventData['datetime_create'] = DateTime.now().toIso8601String();
      eventData['status'] = eventData['status'] ?? 0;

      print('📤 Evento completo para envio: $eventData');
      final response = await post('/api/Events/v1', eventData);
      print('📥 Resposta da API: $response');

      return EventApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao criar evento: $e');
      throw Exception('Erro ao criar evento: $e');
    }
  }

  Future<EventApi> updateEvent(int id, EventApi event) async {
    try {
      print('🔄 === ATUALIZANDO EVENTO ===');

      final eventData = event.toJson();
      eventData['id'] = id;

      // Manter dados do usuário logado
      if (eventData['tenant_id'] == null || eventData['tenant_id'] == 0) {
        eventData['tenant_id'] = _authService.tenantId ?? 0;
      }
      if (eventData['id_enterprise'] == null ||
          eventData['id_enterprise'] == 0) {
        eventData['id_enterprise'] = _authService.idEnterprise ?? 0;
      }
      if (eventData['id_user_create'] == null ||
          eventData['id_user_create'] == 0) {
        eventData['id_user_create'] =
            _authService.usuarioSessao ?? _authService.userId ?? 0;
      }

      print('📤 Dados para atualização: $eventData');
      final response = await put('/api/Events/v1/$id', eventData);
      print('✅ Evento atualizado: $response');

      return EventApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao atualizar evento: $e');
      throw Exception('Erro ao atualizar evento: $e');
    }
  }

  Future<bool> deleteEvent(int id) async {
    try {
      print('🗑️ === DELETANDO EVENTO ===');
      print('ID: $id');
      return await delete('/api/Events/v1/$id');
    } catch (e) {
      print('❌ Erro ao deletar evento: $e');
      throw Exception('Erro ao deletar evento: $e');
    }
  }

  // USERS - SEMPRE autenticados
  Future<List<UserApi>> getUsers({int? userType}) async {
    try {
      print('=== BUSCANDO USUÁRIOS ===');
      String endpoint = '/api/Users/v1';
      if (userType != null) {
        endpoint += '?userType=$userType';
      }

      final response = await get(endpoint);
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> users;
      if (response is List) {
        users = response;
      } else if (response is Map && response['data'] != null) {
        users = response['data'];
      } else {
        users = [];
      }

      print('📊 Usuários encontrados: ${users.length}');

      return users
          .map((json) => UserApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar usuários: $e');
      throw Exception('Erro ao buscar usuários: $e');
    }
  }

  Future<UserApi> getUserById(int id) async {
    try {
      print('Buscando usuário por ID: $id');
      final response = await get('/api/Users/v1/$id');
      print('Usuário encontrado: $response (tipo: ${response.runtimeType})');

      if (response is Map) {
        return UserApi.fromJson(Map<String, dynamic>.from(response));
      } else {
        throw Exception('Formato de resposta inesperado para usuário por ID');
      }
    } catch (e) {
      print('Erro ao buscar usuário por ID: $e');
      throw Exception('Erro ao buscar usuário por ID: $e');
    }
  }

  // TENANTS - SEMPRE autenticados
  Future<TenantApi> getTenantById(int id) async {
    try {
      print('Buscando tenant por ID: $id');
      final response = await get('/api/Tenants/v1/$id');
      print('Tenant encontrado: $response (tipo: ${response.runtimeType})');

      if (response is Map) {
        return TenantApi.fromJson(Map<String, dynamic>.from(response));
      } else {
        throw Exception('Formato de resposta inesperado para tenant por ID');
      }
    } catch (e) {
      print('Erro ao buscar tenant por ID: $e');
      throw Exception('Erro ao buscar tenant por ID: $e');
    }
  }

  Future<UserApi> createUser(UserApi user) async {
    try {
      print('📝 === CRIANDO NOVO USUÁRIO ===');

      // Obter dados do usuário logado
      final tenantId = _authService.tenantId ?? 0;
      final idEnterprise = _authService.idEnterprise ?? 0;

      final userData = user.toJson();
      userData['tenant_id'] = tenantId;
      userData['id_enterprise'] = idEnterprise;
      userData['userType'] = userData['userType'] ?? 2; // Cliente = 2
      userData['status'] = userData['status'] ?? 0;
      userData['userStatus'] = userData['userStatus'] ?? 0;
      userData['dateTimeStatus'] = DateTime.now().toIso8601String();

      print('📤 Usuário completo para envio: $userData');
      final response = await post('/api/Users/v1', userData);
      print('📥 Resposta da API: $response');

      return UserApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao criar usuário: $e');
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  Future<UserApi> updateUser(int id, UserApi user) async {
    try {
      print('🔄 === ATUALIZANDO USUÁRIO ===');

      final userData = user.toJson();
      userData['id'] = id;

      // Manter dados do usuário logado
      if (userData['tenant_id'] == null || userData['tenant_id'] == 0) {
        userData['tenant_id'] = _authService.tenantId ?? 0;
      }
      if (userData['id_enterprise'] == null || userData['id_enterprise'] == 0) {
        userData['id_enterprise'] = _authService.idEnterprise ?? 0;
      }

      print('📤 Dados para atualização: $userData');
      final response = await put('/api/Users/v1/$id', userData);
      print('✅ Usuário atualizado: $response');

      return UserApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao atualizar usuário: $e');
      throw Exception('Erro ao atualizar usuário: $e');
    }
  }

  // TRANSACTIONS DEFAULT - SEMPRE autenticados
  Future<List<TransactionApi>> getTransactionsDefault() async {
    try {
      print('=== BUSCANDO TRANSAÇÕES DEFAULT ===');
      print('Endpoint: /api/Transactions/v1/TransactionsDefaut');

      final response = await get('/api/Transactions/v1/TransactionsDefaut');
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> transactions;
      if (response is List) {
        transactions = response;
      } else if (response is Map && response['data'] != null) {
        transactions = response['data'];
      } else {
        transactions = [];
      }

      print('📊 Transações encontradas: ${transactions.length}');

      return transactions
          .map((json) =>
              TransactionApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar transações: $e');
      throw Exception('Erro ao buscar transações: $e');
    }
  }

  // PAYMENT EVENTS - SEMPRE autenticados
  Future<List<PaymentEventApi>> getPaymentEventsByEvent(int eventId) async {
    try {
      print('=== BUSCANDO PAGAMENTOS DO EVENTO ===');
      print('Endpoint: /api/PaymentEvents/v1/ByEvent/$eventId');

      final response = await get('/api/PaymentEvents/v1/ByEvent/$eventId');
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> payments;
      if (response is List) {
        payments = response;
      } else if (response is Map && response['data'] != null) {
        payments = response['data'];
      } else {
        payments = [];
      }

      print('📊 Pagamentos encontrados: ${payments.length}');

      return payments
          .map((json) =>
              PaymentEventApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar pagamentos: $e');
      throw Exception('Erro ao buscar pagamentos: $e');
    }
  }

  // EXTRAS - SEMPRE autenticados
  Future<List<ExtraApi>> getExtras() async {
    try {
      print('=== BUSCANDO EXTRAS ===');
      print('Endpoint: /api/Extras/v1');

      final response = await get('/api/Extras/v1');
      print('Resposta: $response (tipo: ${response.runtimeType})');

      List<dynamic> extras;
      if (response is List) {
        extras = response;
      } else if (response is Map && response['data'] != null) {
        extras = response['data'];
      } else {
        extras = [];
      }

      print('📊 Extras encontrados: ${extras.length}');

      return extras
          .map((json) => ExtraApi.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar extras: $e');
      throw Exception('Erro ao buscar extras: $e');
    }
  }

  // EXTRA EVENTS - SEMPRE autenticados
  Future<ExtraEventApi> createExtraEvent(ExtraEventApi extraEvent) async {
    try {
      print('📝 === CRIANDO NOVO EXTRA EVENT ===');
      print('Dados recebidos: ${extraEvent.toJson()}');

      // Obter dados do usuário logado
      final tenantId = _authService.tenantId ?? 0;
      final idEnterprise = _authService.idEnterprise ?? 0;
      final idUserCreate =
          _authService.usuarioSessao ?? _authService.userId ?? 0;

      final extraEventData = extraEvent.toJson();
      extraEventData['tenant_id'] = tenantId;
      extraEventData['id_enterprise'] = idEnterprise;
      extraEventData['id_user_created'] = idUserCreate;
      extraEventData['datetime_created'] = DateTime.now().toIso8601String();

      print('📤 ExtraEvent completo para envio: $extraEventData');
      final response = await post('/api/ExtraEvents/v1', extraEventData);
      print('📥 Resposta da API: $response');

      return ExtraEventApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao criar extra event: $e');
      throw Exception('Erro ao criar extra event: $e');
    }
  }

  Future<PaymentEventApi> createPaymentEvent(PaymentEventApi payment) async {
    try {
      print('📝 === CRIANDO NOVO PAGAMENTO ===');

      // Obter dados do usuário logado
      final tenantId = _authService.tenantId ?? 0;
      final idEnterprise = _authService.idEnterprise ?? 0;
      final idUserCreate =
          _authService.usuarioSessao ?? _authService.userId ?? 0;

      final paymentData = payment.toJson();
      paymentData['tenant_id'] = tenantId;
      paymentData['id_enterprise'] = idEnterprise;
      paymentData['id_user_created'] = idUserCreate;
      paymentData['datetime_created'] = DateTime.now().toIso8601String();
      paymentData['status'] = paymentData['status'] ?? 1;
      paymentData['id_user_status'] = idUserCreate;
      paymentData['datetime_status'] = DateTime.now().toIso8601String();
      
      // Se date_vigency não foi fornecido, usar date_payment
      if (paymentData['date_vigency'] == null && paymentData['date_payment'] != null) {
        paymentData['date_vigency'] = paymentData['date_payment'];
      }
      // Se date_payment não foi fornecido, usar date_vigency
      if (paymentData['date_payment'] == null && paymentData['date_vigency'] != null) {
        paymentData['date_payment'] = paymentData['date_vigency'];
      }

      print('📤 Pagamento completo para envio: $paymentData');
      final response = await post('/api/PaymentEvents/v1', paymentData);
      print('📥 Resposta da API: $response');

      return PaymentEventApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao criar pagamento: $e');
      throw Exception('Erro ao criar pagamento: $e');
    }
  }

  Future<PaymentEventApi> updatePaymentEvent(
      int id, PaymentEventApi payment) async {
    try {
      print('🔄 === ATUALIZANDO PAGAMENTO ===');

      final paymentData = payment.toJson();
      paymentData['id'] = id;

      // Manter dados do usuário logado
      if (paymentData['tenant_id'] == null || paymentData['tenant_id'] == 0) {
        paymentData['tenant_id'] = _authService.tenantId ?? 0;
      }
      if (paymentData['id_enterprise'] == null ||
          paymentData['id_enterprise'] == 0) {
        paymentData['id_enterprise'] = _authService.idEnterprise ?? 0;
      }
      if (paymentData['id_user_create'] == null ||
          paymentData['id_user_create'] == 0) {
        paymentData['id_user_create'] =
            _authService.usuarioSessao ?? _authService.userId ?? 0;
      }

      print('📤 Dados para atualização: $paymentData');
      final response = await put('/api/PaymentEvents/v1/$id', paymentData);
      print('✅ Pagamento atualizado: $response');

      return PaymentEventApi.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Erro ao atualizar pagamento: $e');
      throw Exception('Erro ao atualizar pagamento: $e');
    }
  }
}
