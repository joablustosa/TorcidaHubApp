import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/api_models.dart';
import '../../services/evento_service.dart';
import '../../services/cliente_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final EventoService _eventoService = EventoService();
  final ClienteService _clienteService = ClienteService();

  List<EventApi> _eventosPagas = [];
  List<UserApi> _clientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Inicializar serviços
      await _eventoService.initialize();
      await _clienteService.initialize();

      // Carregar eventos e clientes
      await _eventoService.refreshEventos();
      final clientes = await _clienteService.getClientesApi();

      // Obter eventos confirmados (status = 1) usando EventApi
      final eventosApi = await _eventoService.getEventsApi();
      final eventosConfirmados = eventosApi.where((e) => e.status == 1).toList();

      setState(() {
        _eventosPagas = eventosConfirmados;
        _clientes = clientes;
        _isLoading = false;
      });

      print('Eventos pagas carregadas: ${_eventosPagas.length}');
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Obter nome do cliente pelo ID
  String _getNomeCliente(int clienteId) {
    try {
      final cliente = _clientes.firstWhere((c) => c.id == clienteId);
      return cliente.nomeCompleto;
    } catch (e) {
      return 'Cliente ID: $clienteId';
    }
  }

  // Obter endereço do cliente pelo ID
  String _getEnderecoCliente(int clienteId) {
    try {
      final cliente = _clientes.firstWhere((c) => c.id == clienteId);
      return cliente.address ?? 'Endereço não disponível';
    } catch (e) {
      return 'Endereço não disponível';
    }
  }

  // Formatar valor monetário no formato brasileiro (R$ 1.234,56)
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  // Deletar pagamento (desmarcar como confirmado)
  Future<void> _deletarPagamento(EventApi evento) async {
    try {
      // Mostrar dialog de confirmação
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text(
              'Deseja realmente excluir o pagamento da evento do cliente ${_getNomeCliente(evento.id_client)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        // Atualizar o evento para status = 0 (não confirmado)
        final eventoAtualizado = EventApi(
          id: evento.id,
          id_client: evento.id_client,
          date_event: evento.date_event,
          hour_event: evento.hour_event,
          hour_end: evento.hour_end,
          total: evento.total,
          id_user_create: evento.id_user_create,
          datetime_create: evento.datetime_create,
          status: 0, // Não confirmado
          datetime_status: null,
          signal_payment: null,
          // Copiar outros campos necessários
          week_day: evento.week_day,
          birthday_person_one: evento.birthday_person_one,
          age_birthday_person_one: evento.age_birthday_person_one,
          birthday_person_two: evento.birthday_person_two,
          age_birthday_person_two: evento.age_birthday_person_two,
          beer: evento.beer,
          beer_brand: evento.beer_brand,
          cake: evento.cake,
          filling: evento.filling,
          candy: evento.candy,
          broth: evento.broth,
          cake_with_ice_cream: evento.cake_with_ice_cream,
          theme: evento.theme,
          image_theme: evento.image_theme,
          color_balloons: evento.color_balloons,
          arc_balloons_type: evento.arc_balloons_type,
          music: evento.music,
          theme_description: evento.theme_description,
          guests: evento.guests,
          courtesy: evento.courtesy,
          signalOne: evento.signalOne,
          missing_payment: evento.missing_payment,
          amount: evento.amount,
          father_name: evento.father_name,
          mother_name: evento.mother_name,
          value_package: evento.value_package,
          best_day: evento.best_day,
          id_enterprise: evento.id_enterprise,
          id_package: evento.id_package,
          package: evento.package,
          id_local_view: evento.id_local_view,
          local_view: evento.local_view,
          event_code: evento.event_code,
          tenant_id: evento.tenant_id,
        );

        final apiService = _eventoService as dynamic;
        final resultado = await apiService._apiService.updateEvent(evento.id, eventoAtualizado);

        if (resultado != null) {
          // Recarregar dados
          await _carregarDados();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pagamento excluído com sucesso!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao deletar pagamento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao deletar pagamento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPago =
        _eventosPagas.fold(0.0, (sum, evento) => sum + evento.total);
    final esteMesPago = _eventosPagas.where((evento) {
      try {
        final dataEvento = DateTime.parse(
            evento.hour_event ?? evento.date_event ?? '');
        return dataEvento.month == DateTime.now().month &&
            dataEvento.year == DateTime.now().year;
      } catch (e) {
        return false;
      }
    }).fold(0.0, (sum, evento) => sum + evento.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamentos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'Voltar à Agenda',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
            tooltip: 'Atualizar dados',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando pagamentos...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com resumo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Histórico de Pagamentos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total recebido: ${_formatCurrency(totalPago)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cards de resumo
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Este Mês',
                          _formatCurrency(esteMesPago),
                          Icons.calendar_today,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Pago',
                          '${_eventosPagas.length}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Lista de pagamentos
                  Container(
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.history, color: Colors.blue),
                              const SizedBox(width: 12),
                              const Text(
                                'Eventos Pagas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_eventosPagas.length} itens',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_eventosPagas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payment_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Nenhum pagamento encontrado',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'As eventos confirmadas aparecerão aqui',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._eventosPagas
                              .map((evento) => _buildPaymentItem(evento)),
                      ],
                    ),
                  ),
                ],
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
          Icon(icon, color: color, size: 32),
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

  Widget _buildPaymentItem(EventApi evento) {
    // Fazer parse seguro da data
    DateTime dataEvento;
    try {
      dataEvento = DateTime.parse(
          evento.hour_event ?? evento.date_event ?? '');
    } catch (e) {
      dataEvento = DateTime.now();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
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
                  _getNomeCliente(evento.id_client),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy', 'pt_BR').format(dataEvento),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getEnderecoCliente(evento.id_client),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (evento.signal_payment != null &&
                    evento.signal_payment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Forma: ${evento.signal_payment}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
                Text(
                  _formatCurrency(evento.total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pago',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => _deletarPagamento(evento),
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: 'Excluir pagamento',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
