import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../constants/app_colors.dart';

class CreateEventDialog extends StatefulWidget {
  final String fanClubId;
  final String fanClubName;
  final VoidCallback? onEventCreated;

  const CreateEventDialog({
    super.key,
    required this.fanClubId,
    required this.fanClubName,
    this.onEventCreated,
  });

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthServiceSupabase();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _eventType = 'game';
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  DateTime? _registrationDeadline;
  bool _isPaid = false;
  bool _isLoading = false;

  final List<Map<String, String>> _eventTypes = [
    {'value': 'game', 'label': 'Jogo'},
    {'value': 'travel', 'label': 'Viagem'},
    {'value': 'meeting', 'label': 'Reunião'},
    {'value': 'party', 'label': 'Festa'},
    {'value': 'other', 'label': 'Outro'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _locationAddressController.dispose();
    _maxParticipantsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isEndDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEndDate ? (_endDate ?? DateTime.now()) : (_eventDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _eventDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isEndTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isEndTime ? (_endTime ?? TimeOfDay.now()) : (_eventTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isEndTime) {
          _endTime = picked;
        } else {
          _eventTime = picked;
        }
      });
    }
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _registrationDeadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null || _eventTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha a data e horário do evento'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final eventDateTime = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        _eventTime!.hour,
        _eventTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      await SupabaseService.client.from('events').insert({
        'fan_club_id': widget.fanClubId,
        'created_by': _authService.userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'event_type': _eventType,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'location_address': _locationAddressController.text.trim().isEmpty
            ? null
            : _locationAddressController.text.trim(),
        'event_date': eventDateTime.toIso8601String(),
        'end_date': endDateTime?.toIso8601String(),
        'max_participants': _maxParticipantsController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxParticipantsController.text.trim()),
        'is_paid': _isPaid,
        'price': _isPaid && _priceController.text.trim().isNotEmpty
            ? double.tryParse(_priceController.text.trim()) ?? 0.0
            : 0.0,
        'registration_deadline': _registrationDeadline?.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento criado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
        widget.onEventCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar evento: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Criar Novo Evento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          hintText: 'Ex: Jogo contra o Rival',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Tipo de evento
                      DropdownButtonFormField<String>(
                        value: _eventType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Evento',
                          border: OutlineInputBorder(),
                        ),
                        items: _eventTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['value'],
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _eventType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Descrição
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'Detalhes do evento...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // Data e horário
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _eventDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_eventDate!)
                                      : 'Selecione',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Horário *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _eventTime != null
                                      ? _eventTime!.format(context)
                                      : 'Selecione',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Data e horário término
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data Término',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _endDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                      : 'Opcional',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Horário Término',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _endTime != null
                                      ? _endTime!.format(context)
                                      : 'Opcional',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Local
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Local',
                          hintText: 'Ex: Estádio Municipal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Endereço
                      TextFormField(
                        controller: _locationAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Endereço',
                          hintText: 'Endereço completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Limite de participantes
                      TextFormField(
                        controller: _maxParticipantsController,
                        decoration: const InputDecoration(
                          labelText: 'Limite de Participantes',
                          hintText: 'Deixe vazio para ilimitado',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // Prazo de inscrição
                      InkWell(
                        onTap: () => _selectDeadline(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Prazo de Inscrição',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _registrationDeadline != null
                                ? DateFormat('dd/MM/yyyy HH:mm').format(_registrationDeadline!)
                                : 'Opcional',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Evento pago
                      SwitchListTile(
                        title: const Text('Evento Pago'),
                        subtitle: const Text('Cobrar inscrição dos participantes'),
                        value: _isPaid,
                        onChanged: (value) {
                          setState(() {
                            _isPaid = value;
                          });
                        },
                      ),
                      // Valor
                      if (_isPaid) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                            prefixText: 'R\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (_isPaid && (value == null || value.trim().isEmpty)) {
                              return 'Campo obrigatório para eventos pagos';
                            }
                            if (value != null && value.trim().isNotEmpty) {
                              final price = double.tryParse(value.trim());
                              if (price == null || price < 0) {
                                return 'Valor inválido';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Criar Evento'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

