import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../models/evento.dart';
import '../../models/api_models.dart';
import '../../services/evento_service.dart';
import '../../services/cliente_service.dart';
import 'day_details_screen.dart';
import 'event_payments_screen.dart';

enum ViewMode { day, week, month, agenda }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  ViewMode _viewMode = ViewMode.month;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final EventoService _eventoService = EventoService();
  final ClienteService _clienteService = ClienteService();
  List<UserApi> _clientes = [];
  List<Evento> _allEventos = [];
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeLocale();
    _loadEvents();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('pt_BR', null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {});

      await _eventoService.initialize();
      await _clienteService.initialize();

      // Recarregar eventos da API para garantir que estão atualizados no carregamento inicial
      await _eventoService.refreshEventos();

      final clientes = await _clienteService.getClientesApi();
      final eventos = _eventoService.eventos;
      setState(() {
        _clientes = clientes;
        _allEventos = eventos;
      });
    } catch (e) {
      print('Erro ao carregar eventos: $e');
      setState(() {});
    }
  }

  List<Evento> _getEventosForDay(DateTime day) {
    final eventos = _eventoService.getEventosByDate(day);
    return _filterEventos(eventos);
  }

  List<Evento> _filterEventos(List<Evento> eventos) {
    if (_searchQuery.isEmpty) {
      return eventos;
    }
    final query = _searchQuery.toLowerCase();
    return eventos.where((evento) {
      final clienteNome = _getClienteNome(evento.id_cliente).toLowerCase();
      return clienteNome.contains(query);
    }).toList();
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
      return cliente.address ?? '';
    } catch (e) {
      return 'Endereço não encontrado';
    }
  }


  void _changeViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
      if (mode == ViewMode.week) {
        _calendarFormat = CalendarFormat.week;
      } else if (mode == ViewMode.month) {
        _calendarFormat = CalendarFormat.month;
      } else if (mode == ViewMode.day) {
        _calendarFormat = CalendarFormat.week;
      }
    });
    Navigator.pop(context); // Fechar o drawer
  }

  Future<void> _showMonthYearPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione o mês e ano',
    );
    if (picked != null) {
      final newDate = DateTime(picked.year, picked.month, 1);
      if (newDate != _focusedDay) {
        setState(() {
          _focusedDay = newDate;
          _selectedDay = newDate;
        });
      }
    }
  }

  Widget _buildEventList() {
    final eventosDoDia = _getEventosForDay(_selectedDay!);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _viewMode == ViewMode.day
                        ? (_selectedDay!.isAtSameMomentAs(DateTime.now())
                            ? 'HOJE'
                            : DateFormat('EEEE, dd MMMM', 'pt_BR').format(_selectedDay!))
                        : DateFormat('EEEE, dd MMMM', 'pt_BR').format(_selectedDay!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${eventosDoDia.length} ${eventosDoDia.length == 1 ? 'evento' : 'eventos'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (_viewMode == ViewMode.day || _viewMode == ViewMode.month)
                TextButton(
                  onPressed: () async {
                    try {
                      final eventosDoDia = await _eventoService.getEventsByDate(_selectedDay!);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DayDetailsScreen(
                            selectedDay: _selectedDay!,
                            eventos: eventosDoDia,
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Erro ao buscar eventos para o dia: $e');
                      final eventosDoDia = _getEventosForDay(_selectedDay!);
                      final eventosApi = eventosDoDia.map((e) {
                        return EventApi(
                          id: e.id,
                          id_client: e.id_cliente,
                          date_event: e.data_hora_inicio,
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DayDetailsScreen(
                            selectedDay: _selectedDay!,
                            eventos: eventosApi,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: eventosDoDia.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nada agendado. Toque p/ criar.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: eventosDoDia.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(eventosDoDia[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAgendaView() {
    // Agrupar eventos por data
    final eventosFiltrados = _filterEventos(_allEventos);
    eventosFiltrados.sort((a, b) {
      final dateA = a.data_hora_inicio != null ? DateTime.parse(a.data_hora_inicio!) : DateTime(1970);
      final dateB = b.data_hora_inicio != null ? DateTime.parse(b.data_hora_inicio!) : DateTime(1970);
      return dateA.compareTo(dateB);
    });

    final eventosPorData = <String, List<Evento>>{};
    for (var evento in eventosFiltrados) {
      if (evento.data_hora_inicio != null) {
        try {
          final date = DateTime.parse(evento.data_hora_inicio!);
          final key = DateFormat('yyyy-MM-dd', 'pt_BR').format(date);
          eventosPorData.putIfAbsent(key, () => []).add(evento);
        } catch (e) {
          // Ignorar eventos com data inválida
        }
      }
    }

    final sortedDates = eventosPorData.keys.toList()..sort();

    return sortedDates.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Nenhum evento encontrado',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final date = DateTime.parse(dateKey);
              final eventos = eventosPorData[dateKey]!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0, top: index > 0 ? 16.0 : 0),
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'pt_BR').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...eventos.map((evento) => _buildEventCard(evento)),
                ],
              );
            },
          );
  }

  Widget _buildEventCard(Evento evento) {
    DateTime? dataEvento;
    try {
      if (evento.data_hora_inicio != null) {
        dataEvento = DateTime.parse(evento.data_hora_inicio!);
      }
    } catch (e) {
      dataEvento = null;
    }

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventPaymentsScreen(evento: eventoApi),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (dataEvento != null)
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm', 'pt_BR').format(dataEvento),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              if (dataEvento != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getClienteNome(evento.id_cliente),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (dataEvento != null)
                      Text(
                        DateFormat('dd/MM/yyyy', 'pt_BR').format(dataEvento),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _getClienteEndereco(evento.id_cliente),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${evento.valor.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Visualizações',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Dia'),
              selected: _viewMode == ViewMode.day,
              selectedTileColor: Colors.blue[50],
              onTap: () => _changeViewMode(ViewMode.day),
            ),
            ListTile(
              leading: const Icon(Icons.view_week),
              title: const Text('Semana'),
              selected: _viewMode == ViewMode.week,
              selectedTileColor: Colors.blue[50],
              onTap: () => _changeViewMode(ViewMode.week),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Mês'),
              selected: _viewMode == ViewMode.month,
              selectedTileColor: Colors.blue[50],
              onTap: () => _changeViewMode(ViewMode.month),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Agenda'),
              selected: _viewMode == ViewMode.agenda,
              selectedTileColor: Colors.blue[50],
              onTap: () => _changeViewMode(ViewMode.agenda),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu, color: Colors.grey),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                            GestureDetector(
                              onTap: () => _showMonthYearPicker(),
                              child: Row(
                                children: [
                                  Text(
                                    _viewMode == ViewMode.month || _viewMode == ViewMode.week
                                        ? DateFormat('MMMM yyyy', 'pt_BR')
                                            .format(_focusedDay)
                                            .toLowerCase()
                                        : DateFormat('dd MMMM yyyy', 'pt_BR')
                                            .format(_focusedDay)
                                            .toLowerCase(),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _isSearchExpanded ? 200 : 48,
                              child: _isSearchExpanded
                                  ? TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'Buscar...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _isSearchExpanded = false;
                                              _searchQuery = '';
                                              _searchController.clear();
                                            });
                                          },
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
                                      onSubmitted: (_) {
                                        setState(() {
                                          _isSearchExpanded = false;
                                          _searchFocusNode.unfocus();
                                        });
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search, color: Colors.grey),
                                      onPressed: () {
                                        setState(() {
                                          _isSearchExpanded = true;
                                        });
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          _searchFocusNode.requestFocus();
                                        });
                                      },
                                    ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // Navegar para perfil ou fazer login
                                // Por enquanto, apenas navegar para hoje
                                setState(() {
                                  _focusedDay = DateTime.now();
                                  _selectedDay = DateTime.now();
                                });
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey[300],
                                child: const Icon(Icons.person, color: Colors.grey, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_viewMode != ViewMode.agenda)
            TableCalendar<Evento>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              locale: 'pt_BR',
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventosForDay,
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blue[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.grey[600]),
                defaultTextStyle: const TextStyle(color: Colors.black87),
                selectedTextStyle: const TextStyle(color: Colors.white),
                todayTextStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                weekendStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: _viewMode == ViewMode.agenda
                  ? _buildAgendaView()
                  : _buildEventList(),
            ),
          ),
        ],
      ),
    );
  }
}
