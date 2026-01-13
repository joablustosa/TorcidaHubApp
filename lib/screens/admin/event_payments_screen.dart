import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/api_models.dart';
import '../../services/movimentacao_service.dart';
import '../../services/cliente_service.dart';
import '../../services/api_service.dart';
import '../../widgets/add_evento_sheet.dart';

class EventPaymentsScreen extends StatefulWidget {
  final EventApi evento;

  const EventPaymentsScreen({
    super.key,
    required this.evento,
  });

  @override
  State<EventPaymentsScreen> createState() => _EventPaymentsScreenState();
}

class _EventPaymentsScreenState extends State<EventPaymentsScreen> {
  final MovimentacaoService _movimentacaoService = MovimentacaoService();
  final ClienteService _clienteService = ClienteService();
  List<MovimentacaoApi> _movimentacoes = [];
  bool _isLoading = true;
  String? _clienteNome;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _movimentacaoService.initialize();
      await _clienteService.initialize();

      // Carregar pagamentos do evento usando PaymentEvents
      final apiService = ApiService();
      await apiService.initialize();
      final payments =
          await apiService.getPaymentEventsByEvent(widget.evento.id);

      print('📊 Total de pagamentos recebidos: ${payments.length}');

      // Converter PaymentEventApi para MovimentacaoApi para compatibilidade temporária
      final movimentacoes = payments.map((p) {
        print(
            '  - Pagamento ID: ${p.id}, Valor: ${p.value}, Descrição: ${p.description}, Método: ${p.payment_method}');
        return MovimentacaoApi(
          id: p.id,
          nome: p.description ?? p.payment_method ?? p.firstName ?? 'Pagamento',
          id_item: widget.evento.id,
          valor: p.value ?? 0.0,
          data_hora_criacao: p.date_payment ??
              p.date_vigency ??
              p.datetime_created ??
              p.last_payment,
          deletado: p.status == 0, // Status 0 = deletado/inativo
        );
      }).toList();

      print('📊 Total de movimentações convertidas: ${movimentacoes.length}');

      // Carregar nome do cliente
      final cliente =
          await _clienteService.getClienteById(widget.evento.id_client);
      _clienteNome = cliente?.nomeCompleto ?? 'Cliente não encontrado';

      setState(() {
        _movimentacoes = movimentacoes;
        _isLoading = false;
      });

      print('✅ Dados carregados: ${_movimentacoes.length} movimentações');
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalPago {
    return _movimentacoes
        .where((m) => !m.deletado)
        .fold(0.0, (sum, m) => sum + m.valor);
  }

  double get _valorEvento {
    return widget.evento.total;
  }

  double get _progresso {
    if (_valorEvento == 0) return 0.0;
    return (_totalPago / _valorEvento).clamp(0.0, 1.0);
  }

  Future<void> _deletarEvento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
            'Deseja realmente excluir este evento? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final apiService = ApiService();
        await apiService.initialize();
        final sucesso = await apiService.deleteEvent(widget.evento.id);

        if (sucesso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evento deletado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Retorna true para indicar que foi deletado
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao deletar evento: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editarEvento() async {
    AddEventoSheet.showForEdit(
      context,
      evento: widget.evento,
      onEventoUpdated: () {
        // Recarregar dados após edição
        _loadData();
      },
      onRefresh: () {
        // Recarregar dados após edição
        _loadData();
      },
    );
  }

  Future<void> _showAddPaymentDialog() async {
    final dataController = TextEditingController();
    final valorController = TextEditingController(text: '0');
    final formaPagamentoController = TextEditingController();
    final observacaoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagamentos no Sistema'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Data Competência
                TextFormField(
                  controller: dataController,
                  decoration: const InputDecoration(
                    labelText: 'Data Competência *',
                    hintText: 'dd/mm/aaaa',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (date != null) {
                      selectedDate = date;
                      dataController.text =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione a data';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Valor
                TextFormField(
                  controller: valorController,
                  decoration: const InputDecoration(
                    labelText: 'Valor *',
                    hintText: 'Valor Pagamento*',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                // Forma de Pagamento
                TextFormField(
                  controller: formaPagamentoController,
                  decoration: const InputDecoration(
                    labelText: 'Forma de Pagamento *',
                    hintText: 'Forma de Pagamento*',
                    prefixIcon: Icon(Icons.payment),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira a forma de pagamento';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Observação
                TextFormField(
                  controller: observacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    hintText: 'Parcela',
                    prefixIcon: Icon(Icons.note),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, selecione a data'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final valor =
                    double.parse(valorController.text.replaceAll(',', '.'));

                // Criar PaymentEventApi para o evento
                final payment = PaymentEventApi(
                  id_event: widget.evento.id,
                  value: valor,
                  payment_method: formaPagamentoController.text,
                  description: observacaoController.text.isNotEmpty
                      ? observacaoController.text
                      : formaPagamentoController.text,
                  date_vigency: selectedDate!.toIso8601String(),
                  date_payment: selectedDate!.toIso8601String(),
                );

                try {
                  final apiService = ApiService();
                  await apiService.initialize();
                  await apiService.createPaymentEvent(payment);

                  Navigator.pop(context);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pagamento adicionado com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao adicionar pagamento: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Salvar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamentos do Evento'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'edit') {
                _editarEvento();
              } else if (value == 'delete') {
                _deletarEvento();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Deletar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header com informações do evento
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _clienteNome ?? 'Cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Valor Total: R\$ ${_valorEvento.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Barra de progresso
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Pago: R\$ ${_totalPago.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${(_progresso * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progresso,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista de pagamentos
                Expanded(
                  child: _movimentacoes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payment,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum pagamento registrado',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toque no botão + para adicionar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _movimentacoes.length,
                          itemBuilder: (context, index) {
                            final movimentacao = _movimentacoes[index];
                            if (movimentacao.deletado)
                              return const SizedBox.shrink();

                            DateTime? dataPagamento;
                            try {
                              if (movimentacao.data_hora_criacao != null) {
                                dataPagamento = DateTime.parse(
                                    movimentacao.data_hora_criacao!);
                              }
                            } catch (e) {
                              dataPagamento = null;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: const Icon(
                                    Icons.payments,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  movimentacao.nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: dataPagamento != null
                                    ? Text(
                                        DateFormat('dd/MM/yyyy HH:mm', 'pt_BR')
                                            .format(dataPagamento),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      )
                                    : null,
                                trailing: Text(
                                  'R\$ ${movimentacao.valor.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Pagamento'),
      ),
    );
  }
}
