import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/api_models.dart';
import '../models/evento.dart';
import '../services/cliente_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AddEventoSheet extends StatefulWidget {
  final DateTime? initialDate;
  final EventApi? evento; // Evento para edição
  final Function(Evento)? onEventoSaved;
  final Function()? onRefresh;
  final Function()? onEventoUpdated;

  const AddEventoSheet({
    super.key,
    this.initialDate,
    this.evento,
    this.onEventoSaved,
    this.onRefresh,
    this.onEventoUpdated,
  });

  @override
  State<AddEventoSheet> createState() => _AddEventoSheetState();

  static void show(
    BuildContext context, {
    DateTime? initialDate,
    Function(Evento)? onEventoSaved,
    Function()? onRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventoSheet(
        initialDate: initialDate,
        onEventoSaved: onEventoSaved,
        onRefresh: onRefresh,
      ),
    );
  }

  static void showForEdit(
    BuildContext context, {
    required EventApi evento,
    Function()? onEventoUpdated,
    Function()? onRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventoSheet(
        evento: evento,
        onEventoUpdated: onEventoUpdated,
        onRefresh: onRefresh,
      ),
    );
  }
}

class _AddEventoSheetState extends State<AddEventoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _birthdayPersonOneController = TextEditingController();
  final _ageBirthdayPersonOneController = TextEditingController();
  final _signalOneController = TextEditingController();
  final _packageController = TextEditingController();
  DateTime _selectedDateInicio = DateTime.now();
  TimeOfDay _selectedTimeInicio = TimeOfDay.now();
  DateTime _selectedDateFim = DateTime.now();
  TimeOfDay _selectedTimeFim =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));

  UserApi? _clienteSelecionado;
  List<UserApi> _clientes = [];
  bool _isLoadingClientes = true;
  bool _isSaving = false;
  String _signalPayment = 'Dinheiro';
  final ClienteService _clienteService = ClienteService();

  @override
  void initState() {
    super.initState();
    if (widget.evento != null) {
      // Modo de edição - carregar dados do evento
      _loadEventoData();
    } else if (widget.initialDate != null) {
      _selectedDateInicio = widget.initialDate!;
      _selectedDateFim = widget.initialDate!;
    }
    _loadClientes();
  }

  void _loadEventoData() {
    if (widget.evento == null) return;

    final evento = widget.evento!;
    
    // Carregar valores nos controllers
    _valorController.text = evento.total.toStringAsFixed(2).replaceAll('.', ',');
    _birthdayPersonOneController.text = evento.birthday_person_one ?? '';
    _ageBirthdayPersonOneController.text = evento.age_birthday_person_one > 0 
        ? evento.age_birthday_person_one.toString() 
        : '';
    _signalOneController.text = evento.signalOne > 0 
        ? evento.signalOne.toStringAsFixed(2).replaceAll('.', ',') 
        : '';
    _packageController.text = evento.package ?? '';
    _signalPayment = evento.signal_payment ?? 'Dinheiro';

    // Carregar datas e horas
    try {
      if (evento.hour_event != null) {
        final dataHoraInicio = DateTime.parse(evento.hour_event!);
        _selectedDateInicio = dataHoraInicio;
        _selectedTimeInicio = TimeOfDay.fromDateTime(dataHoraInicio);
      }
      if (evento.hour_end != null) {
        final dataHoraFim = DateTime.parse(evento.hour_end!);
        _selectedDateFim = dataHoraFim;
        _selectedTimeFim = TimeOfDay.fromDateTime(dataHoraFim);
      }
    } catch (e) {
      print('Erro ao parsear datas: $e');
    }
  }

  Future<void> _loadClientes() async {
    try {
      await _clienteService.initialize();
      final clientes =
          await _clienteService.getClientesApi(apenasNaoDeletados: true);
      setState(() {
        _clientes = clientes;
        _isLoadingClientes = false;
        // Se estiver em modo de edição, definir o cliente selecionado
        if (widget.evento != null && _clienteSelecionado == null) {
          _clienteSelecionado = clientes.firstWhere(
            (c) => c.id == widget.evento!.id_client,
            orElse: () => clientes.first,
          );
        }
      });
      print('✅ Clientes carregados para select: ${_clientes.length}');
    } catch (e) {
      print('❌ Erro ao carregar clientes: $e');
      setState(() {
        _isLoadingClientes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.evento != null ? 'Editar Evento' : 'Novo Evento',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Seletor de cliente
                        if (_isLoadingClientes)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          DropdownButtonFormField<UserApi>(
                            value: _clienteSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Cliente',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.person, color: Colors.blue),
                            ),
                            hint: const Text('Selecione um cliente'),
                            items: _clientes.map((cliente) {
                              return DropdownMenuItem<UserApi>(
                                value: cliente,
                                child: Text(cliente.nomeCompleto),
                              );
                            }).toList(),
                            onChanged: (UserApi? cliente) {
                              setState(() {
                                _clienteSelecionado = cliente;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor, selecione um cliente';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 16),
                        // Endereço (readonly)
                        if (_clienteSelecionado != null)
                          TextFormField(
                            initialValue: _clienteSelecionado!.address ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Endereço',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.location_on, color: Colors.blue),
                            ),
                            readOnly: true,
                            enabled: false,
                          ),
                        if (_clienteSelecionado != null)
                          const SizedBox(height: 16),
                        // Campo Valor
                        TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(
                            labelText: 'Valor',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.attach_money, color: Colors.blue),
                            prefixText: 'R\$ ',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira o valor';
                            }
                            if (double.tryParse(value.replaceAll(',', '.')) ==
                                null) {
                              return 'Por favor, insira um valor válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo Nome do Aniversariante
                        TextFormField(
                          controller: _birthdayPersonOneController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Aniversariante',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Campo Idade do Aniversariante
                        TextFormField(
                          controller: _ageBirthdayPersonOneController,
                          decoration: const InputDecoration(
                            labelText: 'Idade do Aniversariante',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.cake, color: Colors.blue),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return 'Por favor, insira uma idade válida';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo Sinal (Entrada)
                        TextFormField(
                          controller: _signalOneController,
                          decoration: const InputDecoration(
                            labelText: 'Sinal (Entrada)',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.payment, color: Colors.blue),
                            prefixText: 'R\$ ',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (double.tryParse(value.replaceAll(',', '.')) ==
                                  null) {
                                return 'Por favor, insira um valor válido';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo Forma de Pagamento
                        DropdownButtonFormField<String>(
                          value: _signalPayment,
                          decoration: const InputDecoration(
                            labelText: 'Forma de Pagamento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment, color: Colors.blue),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Dinheiro', child: Text('Dinheiro')),
                            DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                            DropdownMenuItem(
                                value: 'Crédito', child: Text('Crédito')),
                            DropdownMenuItem(
                                value: 'Débito', child: Text('Débito')),
                            DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _signalPayment = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo Pacote
                        TextFormField(
                          controller: _packageController,
                          decoration: const InputDecoration(
                            labelText: 'Pacote',
                            hintText: 'Digite o nome do pacote',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Data e Hora de Início
                        const Text(
                          'Data e Hora de Início',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateInicio,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _selectedDateInicio = date;
                                      // Se a data de fim for anterior à nova data de início, atualizar também
                                      if (_selectedDateFim.isBefore(date) ||
                                          (_selectedDateFim
                                                  .isAtSameMomentAs(date) &&
                                              _selectedTimeFim.hour * 60 +
                                                      _selectedTimeFim.minute <=
                                                  _selectedTimeInicio.hour *
                                                          60 +
                                                      _selectedTimeInicio
                                                          .minute)) {
                                        _selectedDateFim = date;
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text(
                                        DateFormat('dd/MM/yyyy', 'pt_BR')
                                            .format(_selectedDateInicio),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTimeInicio,
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _selectedTimeInicio = time;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedTimeInicio.format(context),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Data e Hora de Fim
                        const Text(
                          'Data e Hora de Fim',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateFim,
                                    firstDate: _selectedDateInicio,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _selectedDateFim = date;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text(
                                        DateFormat('dd/MM/yyyy', 'pt_BR')
                                            .format(_selectedDateFim),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTimeFim,
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _selectedTimeFim = time;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedTimeFim.format(context),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Footer com botões
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveEvento,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  widget.evento != null ? 'Salvar Alterações' : 'Adicionar Evento',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveEvento() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar se data/hora fim é posterior à data/hora início
    final dataHoraInicio = DateTime(
      _selectedDateInicio.year,
      _selectedDateInicio.month,
      _selectedDateInicio.day,
      _selectedTimeInicio.hour,
      _selectedTimeInicio.minute,
    );

    final dataHoraFim = DateTime(
      _selectedDateFim.year,
      _selectedDateFim.month,
      _selectedDateFim.day,
      _selectedTimeFim.hour,
      _selectedTimeFim.minute,
    );

    if (dataHoraFim.isBefore(dataHoraInicio) ||
        dataHoraFim.isAtSameMomentAs(dataHoraInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'A data/hora de fim deve ser posterior à data/hora de início'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = AuthService();
      await authService.initialize();
      final userId = authService.userId ?? 0;

      // Criar ou atualizar EventApi com os dados do formulário
      final signalOneValue = _signalOneController.text.isNotEmpty
          ? double.parse(_signalOneController.text.replaceAll(',', '.'))
          : 0.0;
      final ageBirthdayPersonOne = _ageBirthdayPersonOneController.text.isNotEmpty
          ? int.parse(_ageBirthdayPersonOneController.text)
          : 0;

      final eventoOriginal = widget.evento;
      final isEditing = eventoOriginal != null;

      EventApi evento;
      if (isEditing) {
        // Modo de edição - manter dados originais
        final original = eventoOriginal!;
        evento = EventApi(
          id: original.id,
          id_client: _clienteSelecionado!.id,
          date_event: dataHoraInicio.toIso8601String(),
          hour_event: dataHoraInicio.toIso8601String(),
          hour_end: dataHoraFim.toIso8601String(),
          total: double.parse(_valorController.text.replaceAll(',', '.')),
          id_user_create: eventoOriginal.id_user_create,
          datetime_create: eventoOriginal.datetime_create,
          datetime_status: DateTime.now().toIso8601String(),
          status: eventoOriginal.status,
          id_enterprise: eventoOriginal.id_enterprise,
          tenant_id: eventoOriginal.tenant_id,
          birthday_person_one: _birthdayPersonOneController.text.isNotEmpty
              ? _birthdayPersonOneController.text
              : '',
          age_birthday_person_one: ageBirthdayPersonOne,
          birthday_person_two: eventoOriginal.birthday_person_two,
          age_birthday_person_two: eventoOriginal.age_birthday_person_two,
          beer_brand: eventoOriginal.beer_brand,
          cake: eventoOriginal.cake,
          filling: eventoOriginal.filling,
          candy: eventoOriginal.candy,
          broth: eventoOriginal.broth,
          theme: eventoOriginal.theme,
          image_theme: eventoOriginal.image_theme,
          music: eventoOriginal.music,
          theme_description: eventoOriginal.theme_description,
          color_balloons: eventoOriginal.color_balloons,
          signalOne: signalOneValue,
          signal_payment: _signalPayment,
          father_name: eventoOriginal.father_name,
          mother_name: eventoOriginal.mother_name,
          package: _packageController.text.isNotEmpty
              ? _packageController.text
              : eventoOriginal.package,
          local_view: eventoOriginal.local_view,
        );
      } else {
        // Modo de criação
        evento = EventApi(
          id: 0,
          id_client: _clienteSelecionado!.id,
          date_event: dataHoraInicio.toIso8601String(),
          hour_event: dataHoraInicio.toIso8601String(),
          hour_end: dataHoraFim.toIso8601String(),
          total: double.parse(_valorController.text.replaceAll(',', '.')),
          id_user_create: authService.usuarioSessao ?? userId,
          datetime_create: DateTime.now().toIso8601String(),
          datetime_status: DateTime.now().toIso8601String(),
          status: 1,
          id_enterprise: authService.idEnterprise ?? 0,
          tenant_id: authService.tenantId ?? 0,
          birthday_person_one: _birthdayPersonOneController.text.isNotEmpty
              ? _birthdayPersonOneController.text
              : '',
          age_birthday_person_one: ageBirthdayPersonOne,
          birthday_person_two: null,
          age_birthday_person_two: 0,
          beer_brand: 'Escolher depois',
          cake: 'Escolher depois',
          filling: 'Escolher depois',
          candy: 'Escolher depois',
          broth: 'Escolher depois',
          theme: 'Escolher depois',
          image_theme: 'Escolher depois',
          music: '-',
          theme_description: 'Escolher depois',
          color_balloons: '',
          signalOne: signalOneValue,
          signal_payment: _signalPayment,
          father_name: 'Preencher depois',
          mother_name: 'Preencher depois',
          package: _packageController.text.isNotEmpty
              ? _packageController.text
              : null,
          local_view: 'App',
        );
      }

      final apiService = ApiService();
      await apiService.initialize();
      
      EventApi eventoAtualizado;
      if (isEditing) {
        final original = eventoOriginal!;
        eventoAtualizado = await apiService.updateEvent(original.id, evento);
      } else {
        eventoAtualizado = await apiService.createEvent(evento);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing 
                ? 'Evento atualizado com sucesso!' 
                : 'Evento adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        if (isEditing && widget.onEventoUpdated != null) {
          widget.onEventoUpdated!();
        }

        if (!isEditing && widget.onEventoSaved != null) {
          // Converter EventApi para Evento para compatibilidade
          final eventoCompat = Evento(
            id: eventoAtualizado.id,
            data_hora_criacao:
                eventoAtualizado.datetime_create ?? DateTime.now().toIso8601String(),
            id_usuario_criacao: eventoAtualizado.id_user_create,
            id_usuario: eventoAtualizado.id_user_create,
            id_cliente: eventoAtualizado.id_client,
            valor: eventoAtualizado.total,
            data_hora_inicio: eventoAtualizado.hour_event ??
                eventoAtualizado.date_event ??
                DateTime.now().toIso8601String(),
            data_hora_fim:
                eventoAtualizado.hour_end ?? DateTime.now().toIso8601String(),
            confirmado: eventoAtualizado.status == 1,
            prioridade: 0,
            deletado: false,
          );
          widget.onEventoSaved!(eventoCompat);
        }

        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar evento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _valorController.dispose();
    _birthdayPersonOneController.dispose();
    _ageBirthdayPersonOneController.dispose();
    _signalOneController.dispose();
    _packageController.dispose();
    super.dispose();
  }
}
