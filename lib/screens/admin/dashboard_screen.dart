import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agendadefesta/models/evento.dart';
import 'package:agendadefesta/models/api_models.dart';
import 'package:agendadefesta/services/cliente_service.dart';
import '../../services/evento_service.dart';
import '../../services/api_service.dart';
import 'event_payments_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EventoService _eventoService = EventoService();
  final ClienteService _clienteService = ClienteService();
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<TransactionApi> _transactions = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _apiService.initialize();
      await _eventoService.initialize();
      await _clienteService.initialize();

      // Carregar transações da API
      final transactions = await _apiService.getTransactionsDefault();

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao inicializar dashboard: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalRecebido {
    return _transactions
        .where((t) => t.id_sub_ibput_type == 1)
        .fold(0.0, (sum, t) => sum + t.value);
  }

  double get _totalMes {
    final currentMonth = DateTime.now();
    return _eventoService.getTotalMes(currentMonth);
  }

  double get _totalPendente {
    return _totalMes - _totalRecebido;
  }

  // Formatar valor monetário no formato brasileiro (R$ 1.234,56)
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentMonth = DateTime.now();
    final totalValue = _totalMes;
    final completedEventos = _eventoService.getQuantidadeRealizadas();
    final pendingValue = _totalPendente;
    final totalEventos = _eventoService.eventos.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Visão Geral',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Visão geral dos eventos',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Voltar à Agenda',
                        ),
                      ],
                    ),
                    Text(
                      '${DateFormat('MMMM yyyy', 'pt_BR').format(currentMonth)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total do Mês',
                      _formatCurrency(totalValue),
                      Icons.attach_money,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Recebido',
                      _formatCurrency(_totalRecebido),
                      Icons.payments,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'A Receber',
                      _formatCurrency(pendingValue),
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total de Eventos',
                      '$totalEventos',
                      Icons.event,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progresso do Mês',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: totalEventos > 0
                          ? completedEventos / totalEventos
                          : 0.0,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completedEventos de $totalEventos eventos confirmados',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Próximos Eventos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._eventoService
                        .getEventosPendentes()
                        .take(3)
                        .map((evento) => _buildNextEventoItem(evento)),
                    if (_eventoService.getEventosPendentes().isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Nenhum evento pendente para este mês',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextEventoItem(Evento evento) {
    return FutureBuilder<List<UserApi>>(
      future: _clienteService.getClientesApi(),
      builder: (context, snapshot) {
        final clientes = snapshot.data ?? [];
        UserApi? cliente;
        try {
          cliente = clientes.firstWhere((c) => c.id == evento.id_cliente);
        } catch (e) {
          cliente = null;
        }

        DateTime? dataEvento;
        try {
          if (evento.data_hora_inicio != null) {
            dataEvento = DateTime.parse(evento.data_hora_inicio!);
          }
        } catch (e) {
          dataEvento = null;
        }

        // Converter Evento para EventApi para navegação
        final eventoApi = EventApi(
          id: evento.id,
          id_client: evento.id_cliente,
          date_event: evento.data_hora_inicio,
          hour_event: evento.data_hora_inicio,
          hour_end: evento.data_hora_fim,
          total: evento.valor,
          id_user_create: evento.id_usuario_criacao,
          datetime_create: evento.data_hora_criacao,
          status: evento.confirmado ? 1 : 0,
          datetime_status: evento.data_hora_confirmado,
          signal_payment: evento.forma_de_pagamento,
        );

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventPaymentsScreen(
                  evento: eventoApi,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente?.nomeCompleto ?? 'Cliente não encontrado',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            dataEvento != null
                                ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR')
                                    .format(dataEvento)
                                : 'Sem data',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toque para ver detalhes e pagamentos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(evento.valor),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
