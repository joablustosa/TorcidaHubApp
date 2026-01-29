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
      initialDate: isEndDate
          ? (_endDate ?? DateTime.now())
          : (_eventDate ?? DateTime.now()),
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
      initialTime: isEndTime
          ? (_endTime ?? TimeOfDay.now())
          : (_eventTime ?? TimeOfDay.now()),
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
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

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
            behavior: SnackBarBehavior.floating,
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const double _radius = 16;
  static const double _inputRadius = 14;

  InputDecoration _decoration(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.6),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _dateTimeChip({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_inputRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: value == 'Selecione' || value == 'Opcional'
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withOpacity(0.6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle (indicador de arraste)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header com gradiente
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.darkGreen],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Criar Novo Evento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seção: Identidade do evento
                      _sectionCard(
                        title: 'Identidade do evento',
                        icon: Icons.edit_rounded,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: _decoration(
                              'Título *',
                              hint: 'Ex: Jogo contra o Rival',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _eventType,
                            decoration: _decoration('Tipo de Evento'),
                            borderRadius: BorderRadius.circular(_inputRadius),
                            dropdownColor: AppColors.surface,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                            items: _eventTypes
                                .map((type) => DropdownMenuItem(
                                      value: type['value'],
                                      child: Text(
                                        type['label']!,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _eventType = v!),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: _decoration(
                              'Descrição',
                              hint: 'Detalhes do evento...',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),

                      // Seção: Data e horário
                      _sectionCard(
                        title: 'Data e horário',
                        icon: Icons.calendar_today_rounded,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _dateTimeChip(
                                  label: 'Data *',
                                  value: _eventDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_eventDate!)
                                      : 'Selecione',
                                  icon: Icons.calendar_today_rounded,
                                  onTap: () => _selectDate(context, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dateTimeChip(
                                  label: 'Horário *',
                                  value: _eventTime != null
                                      ? _eventTime!.format(context)
                                      : 'Selecione',
                                  icon: Icons.schedule_rounded,
                                  onTap: () => _selectTime(context, false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _dateTimeChip(
                                  label: 'Data término',
                                  value: _endDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                      : 'Opcional',
                                  icon: Icons.event_rounded,
                                  onTap: () => _selectDate(context, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dateTimeChip(
                                  label: 'Horário término',
                                  value: _endTime != null
                                      ? _endTime!.format(context)
                                      : 'Opcional',
                                  icon: Icons.schedule_rounded,
                                  onTap: () => _selectTime(context, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção: Local
                      _sectionCard(
                        title: 'Local',
                        icon: Icons.location_on_rounded,
                        children: [
                          TextFormField(
                            controller: _locationController,
                            decoration: _decoration(
                              'Local',
                              hint: 'Ex: Estádio Municipal',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _locationAddressController,
                            decoration: _decoration(
                              'Endereço',
                              hint: 'Endereço completo',
                            ),
                          ),
                        ],
                      ),

                      // Seção: Inscrições
                      _sectionCard(
                        title: 'Inscrições',
                        icon: Icons.people_rounded,
                        children: [
                          TextFormField(
                            controller: _maxParticipantsController,
                            decoration: _decoration(
                              'Limite de participantes',
                              hint: 'Vazio = ilimitado',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectDeadline(context),
                              borderRadius: BorderRadius.circular(_inputRadius),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(_inputRadius),
                                  border: Border.all(
                                      color: AppColors.textSecondary
                                          .withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_rounded,
                                        size: 20, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Prazo de inscrição',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _registrationDeadline != null
                                                ? DateFormat('dd/MM/yyyy HH:mm')
                                                    .format(
                                                        _registrationDeadline!)
                                                : 'Opcional',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: _registrationDeadline !=
                                                      null
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textSecondary
                                          .withOpacity(0.6),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(_radius),
                              border: Border.all(
                                color: AppColors.textSecondary.withOpacity(0.1),
                              ),
                            ),
                            child: SwitchListTile(
                              title: const Text(
                                'Evento pago',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                'Cobrar valor na inscrição',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              value: _isPaid,
                              onChanged: (v) => setState(() => _isPaid = v),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (_isPaid) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _priceController,
                              decoration: _decoration(
                                'Valor (R\$) *',
                                hint: '0,00',
                              ).copyWith(
                                prefixText: 'R\$ ',
                                prefixStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (_isPaid &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Obrigatório para evento pago';
                                }
                                if (v != null && v.trim().isNotEmpty) {
                                  final price = double.tryParse(
                                      v.trim().replaceAll(',', '.'));
                                  if (price == null || price < 0) {
                                    return 'Valor inválido';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Botões de ação
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: BorderSide(
                                    color: AppColors.textSecondary
                                        .withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(_inputRadius),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(_inputRadius),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
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
