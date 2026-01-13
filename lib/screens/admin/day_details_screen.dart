import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/api_models.dart';
import '../../services/cliente_service.dart';
import '../../services/evento_service.dart';
import 'event_payments_screen.dart';
import '../../widgets/add_evento_sheet.dart';

class DayDetailsScreen extends StatefulWidget {
  final DateTime selectedDay;
  final List<dynamic> eventos; // Aceita EventApi ou EventoApi para compatibilidade

  const DayDetailsScreen({
    super.key,
    required this.selectedDay,
    required this.eventos,
  });

  @override
  State<DayDetailsScreen> createState() => _DayDetailsScreenState();
}

class _DayDetailsScreenState extends State<DayDetailsScreen> {
  late List<EventApi> _eventos;
  final ClienteService _clienteService = ClienteService();
  final EventoService _eventoService = EventoService();
  List<UserApi> _clientes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Converter EventoApi para EventApi se necessário
    _eventos = widget.eventos.map((e) {
      // Se já for EventApi, retornar como está
      if (e is EventApi) {
        return e;
      }
      // Se for EventoApi antigo, converter (manter compatibilidade temporária)
      return EventApi(
        id: e.id,
        id_client: e.id_cliente,
        date_event: e.data_hora_evento,
        hour_event: e.data_hora_inicio,
        hour_end: e.data_hora_fim,
        total: e.valor,
        id_user_create: e.id_usuario_criacao,
        datetime_create: e.data_hora_criacao,
        status: e.confirmado ? 1 : 0,
        datetime_status: e.data_hora_confirmado,
        signal_payment: e.forma_de_pagamento,
      );
    }).toList();
    _loadClientes();
    _loadEventosFromApi();
  }

  Future<void> _loadClientes() async {
    try {
      // Buscar apenas clientes não deletados para o select
      final clientes =
          await _clienteService.getClientesApi(apenasNaoDeletados: true);
      setState(() {
        _clientes = clientes;
      });
      print('✅ Clientes carregados para select: ${_clientes.length}');
    } catch (e) {
      print('❌ Erro ao carregar clientes: $e');
    }
  }

  String _getClienteNome(int clienteId) {
    try {
      final cliente = _clientes.firstWhere((c) => c.id == clienteId);
      return cliente.nomeCompleto;
    } catch (e) {
      return 'Cliente #$clienteId';
    }
  }

  String _getClienteEndereco(int clienteId) {
    try {
      final cliente = _clientes.firstWhere((c) => c.id == clienteId);
      return cliente.address ?? 'Endereço não encontrado';
    } catch (e) {
      return 'Endereço não encontrado';
    }
  }

  Future<void> _loadEventosFromApi() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Usar o novo método que retorna EventApi
      final eventosDoDia = await _eventoService.getEventsByDate(widget.selectedDay);

      setState(() {
        _eventos = eventosDoDia;
        _isLoading = false;
      });

      print(
          'Eventos carregados da API para ${widget.selectedDay}: ${_eventos.length} encontrados');
    } catch (e) {
      print('Erro ao carregar eventos da API: $e');
      setState(() {
        _isLoading = false;
      });
      // Em caso de erro, manter os eventos passados como parâmetro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showAddEventoDialog() {
    AddEventoSheet.show(
      context,
      initialDate: widget.selectedDay,
      onEventoSaved: (evento) async {
        // Recarregar eventos da API para atualizar a lista
        await _loadEventosFromApi();
      },
      onRefresh: () async {
        // Recarregar eventos da API para atualizar a lista
        await _loadEventosFromApi();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('dd/MM/yyyy', 'pt_BR').format(widget.selectedDay),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEventosFromApi,
            tooltip: 'Atualizar dados',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // Navega de volta para a agenda principal
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'Voltar à Agenda',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEventoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header com informações do dia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE', 'pt_BR')
                      .format(widget.selectedDay)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd MMMM yyyy', 'pt_BR')
                      .format(widget.selectedDay),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoCard(
                      'Total de Eventos',
                      '${_eventos.length}',
                      Icons.event,
                    ),
                    _buildInfoCard(
                      'Valor Total',
                      _formatCurrency(_getTotalValue()),
                      Icons.attach_money,
                    ),
                    _buildInfoCard(
                      'Confirmadas',
                      '${_eventos.where((l) => l.status == 1).length}',
                      Icons.check_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de eventos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Carregando eventos...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _eventos.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum evento agendado para este dia',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Toque no botão + para adicionar um novo evento',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _eventos.length,
                        itemBuilder: (context, index) {
                          final evento = _eventos[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                // Evento já é EventApi
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventPaymentsScreen(
                                      evento: evento,
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (evento.status == 1)
                                      ? Colors.blue
                                      : Colors.grey,
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/icon.png',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  _getClienteNome(evento.id_client),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    decoration: (evento.status == 1)
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(DateFormat(
                                                'dd/MM/yyyy HH:mm', 'pt_BR')
                                            .format(_parseDateTime(
                                                evento.hour_event ??
                                                    evento.date_event))),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.location_on,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _getClienteEndereco(evento.id_client),
                                            overflow: TextOverflow.ellipsis,
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatCurrency(evento.total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (evento.status == 1)
                                            ? Colors.grey
                                            : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios,
                                        size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventoDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  double _getTotalValue() {
    return _eventos.fold(0.0, (sum, evento) => sum + evento.total);
  }

  // Formatar valor monetário no formato brasileiro (R$ 1.234,56)
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  // Método auxiliar para fazer parse seguro de data
  DateTime _parseDateTime(String? dataString) {
    try {
      if (dataString == null || dataString.isEmpty) {
        return DateTime.now();
      }
      return DateTime.parse(dataString);
    } catch (e) {
      print('Erro ao fazer parse da data: $dataString - $e');
      return DateTime.now();
    }
  }

}


class PaymentDialog extends StatefulWidget {
  final EventApi evento;
  final Function(double valor, String formaPagamento) onPaymentConfirmed;

  const PaymentDialog({
    super.key,
    required this.evento,
    required this.onPaymentConfirmed,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  String _formaPagamento = 'Dinheiro';
  final ClienteService _clienteService = ClienteService();

  @override
  void initState() {
    super.initState();
    _valorController.text = widget.evento.total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar Pagamento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Informações do evento
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    FutureBuilder<List<UserApi>>(
                    future: _clienteService.getClientesApi(),
                    builder: (context, snapshot) {
                      final clientes = snapshot.data ?? [];
                      String nomeCliente = 'Cliente #${widget.evento.id_client}';
                      String enderecoCliente = 'Endereço não encontrado';
                      
                      try {
                        final cliente = clientes.firstWhere((c) => c.id == widget.evento.id_client);
                        nomeCliente = cliente.nomeCompleto;
                        enderecoCliente = cliente.address ?? 'Endereço não encontrado';
                      } catch (e) {
                        // Usar valores padrão
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomeCliente,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Endereço: $enderecoCliente',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(_parseDateTime(widget.evento.hour_event ?? widget.evento.date_event))}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Campo de valor
            TextFormField(
              controller: _valorController,
              decoration: const InputDecoration(
                labelText: 'Valor Recebido',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o valor';
                }
                final valor = double.tryParse(value.replaceAll(',', '.'));
                if (valor == null || valor <= 0) {
                  return 'Por favor, insira um valor válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Seletor de forma de pagamento
            const Text(
              'Forma de Pagamento:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _formaPagamento,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'Dinheiro', child: Text('💵 Dinheiro')),
                DropdownMenuItem(value: 'Pix', child: Text('📱 Pix')),
                DropdownMenuItem(value: 'Débito', child: Text('💳 Débito')),
                DropdownMenuItem(value: 'Crédito', child: Text('💳 Crédito')),
                DropdownMenuItem(value: 'Outro', child: Text('🔗 Outro')),
              ],
              onChanged: (value) {
                setState(() {
                  _formaPagamento = value!;
                });
              },
            ),

            const SizedBox(height: 24),

            // Campo de Observação
            TextFormField(
              controller: _observacaoController,
              decoration: const InputDecoration(
                labelText: 'Observação',
                hintText: 'Digite uma observação (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final valor = double.parse(_valorController.text.replaceAll(',', '.'));
              widget.onPaymentConfirmed(valor, _formaPagamento);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  // Método auxiliar para fazer parse seguro de data
  DateTime _parseDateTime(String? dataString) {
    try {
      if (dataString == null || dataString.isEmpty) {
        return DateTime.now();
      }
      return DateTime.parse(dataString);
    } catch (e) {
      print('Erro ao fazer parse da data: $dataString - $e');
      return DateTime.now();
    }
  }
}
