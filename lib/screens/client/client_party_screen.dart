import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/api_models.dart';

class ClientPartyScreen extends StatefulWidget {
  const ClientPartyScreen({super.key});

  @override
  State<ClientPartyScreen> createState() => _ClientPartyScreenState();
}

class _ClientPartyScreenState extends State<ClientPartyScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  EventApi? _evento;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.initialize();
      final userId = _authService.userId;
      
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Buscar eventos do cliente
      final eventos = await _apiService.getEvents();
      final eventoDoCliente = eventos.where((e) => e.id_client == userId).firstOrNull;

      setState(() {
        _evento = eventoDoCliente;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Data não informada';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
    } catch (e) {
      return dateStr;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Minha Festa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _carregarDados,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _evento == null
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildCardFesta(),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum evento encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entre em contato com a casa de festas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFesta() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Minha Festa',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Código: #${_evento?.event_code ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoCard(Icons.calendar_today, 'Data do Evento', _formatDate(_evento?.date_event)),
            const SizedBox(height: 16),
            _buildInfoCard(Icons.access_time, 'Horário de Início', _evento?.hour_event ?? 'Não informado'),
            if (_evento?.hour_end != null && _evento!.hour_end!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.access_time_filled, 'Horário de Término', _evento!.hour_end!),
            ],
            const SizedBox(height: 16),
            _buildInfoCard(Icons.monetization_on, 'Valor Total', _formatCurrency(_evento?.total ?? 0.0)),
            if (_evento?.package != null && _evento!.package!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.inventory, 'Pacote', _evento!.package!),
            ],
            if (_evento?.theme != null && _evento!.theme!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.celebration, 'Tema', _evento!.theme!),
            ],
            if (_evento?.theme_description != null && _evento!.theme_description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.description, 'Descrição do Tema', _evento!.theme_description!),
            ],
            if (_evento?.guests != null && _evento!.guests! > 0) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.people, 'Número de Convidados', '${_evento?.guests} pessoas'),
            ],
            if (_evento?.birthday_person_one != null && _evento!.birthday_person_one!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.cake, 'Aniversariante', _evento!.birthday_person_one!),
              if (_evento?.age_birthday_person_one != null && _evento!.age_birthday_person_one! > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    '${_evento?.age_birthday_person_one} anos',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
            if (_evento?.local_view != null && _evento!.local_view!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(Icons.location_on, 'Local', _evento!.local_view!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
