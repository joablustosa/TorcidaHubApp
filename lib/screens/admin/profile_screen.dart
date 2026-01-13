import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'payments_screen.dart';
import 'help_support_screen.dart';
import 'cadastrar_cliente_screen.dart';
import '../../services/auth_service.dart';
import '../../services/evento_service.dart';
import '../../services/cliente_service.dart';
import '../../services/usuario_service.dart';
import '../../models/api_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final EventoService _eventoService = EventoService();
  final ClienteService _clienteService = ClienteService();
  final UsuarioService _usuarioService = UsuarioService();
  final AuthService _authService = AuthService();

  int _totalEventos = 0;
  int _totalClientes = 0;
  double _avaliacaoMedia = 0.0;
  bool _isLoading = true;
  UsuarioApi? _usuario;

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
      // Carregar dados em paralelo
      await Future.wait([
        _carregarUsuario(),
        _carregarEstatisticas(),
      ]);
    } catch (e) {
      print('❌ Erro ao carregar dados: $e');
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

  Future<void> _carregarUsuario() async {
    try {
      // Inicializar serviço
      await _usuarioService.initialize();

      final userId = _authService.userId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final usuario = await _usuarioService.getUsuarioById(userId);
      setState(() {
        _usuario = usuario;
      });

      print('✅ Dados do usuário carregados: ${usuario.nome}');
    } catch (e) {
      print('❌ Erro ao carregar usuário: $e');
      // Usar dados padrão em caso de erro
      setState(() {
        _usuario = UsuarioApi(
          id: 0,
          deletado: false,
          id_usuario_criacao: 0,
          nome: 'Usuário',
          email: 'usuario@email.com',
          telefone: '(11) 99999-9999',
          senha: '',
        );
      });
    }
  }

  Future<void> _carregarEstatisticas() async {
    try {
      // Carregar estatísticas em paralelo
      await Future.wait([
        _carregarTotalEventos(),
        _carregarTotalClientes(),
        _carregarAvaliacaoMedia(),
      ]);
    } catch (e) {
      print('❌ Erro ao carregar estatísticas: $e');
    }
  }

  Future<void> _carregarTotalEventos() async {
    try {
      await _eventoService.refreshEventos();
      setState(() {
        _totalEventos = _eventoService.eventos.length;
      });
      print('✅ Total de eventos carregado: $_totalEventos');
    } catch (e) {
      print('❌ Erro ao carregar total de eventos: $e');
      setState(() {
        _totalEventos = 0;
      });
    }
  }

  Future<void> _carregarTotalClientes() async {
    try {
      final clientes = await _clienteService.getClientes();
      setState(() {
        _totalClientes = clientes.length;
      });
      print('✅ Total de clientes carregado: $_totalClientes');
    } catch (e) {
      print('❌ Erro ao carregar total de clientes: $e');
      setState(() {
        _totalClientes = 0;
      });
    }
  }

  Future<void> _carregarAvaliacaoMedia() async {
    try {
      // Por enquanto usando valor padrão, mas pode ser implementado com API real
      // quando houver endpoint de avaliações
      setState(() {
        _avaliacaoMedia = 4.8; // Valor padrão até implementar API de avaliações
      });
      print('✅ Avaliação média carregada: $_avaliacaoMedia');
    } catch (e) {
      print('❌ Erro ao carregar avaliação média: $e');
      setState(() {
        _avaliacaoMedia = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarDados,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header do perfil
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/icon.png',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildProfileStat(
                              'Eventos', _isLoading ? '...' : '$_totalEventos'),
                          _buildProfileStat('Clientes',
                              _isLoading ? '...' : '$_totalClientes'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Opções do perfil
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildProfileOption(
                        icon: Icons.person_add,
                        title: 'Cadastrar Cliente',
                        subtitle: 'Adicionar novo cliente ao sistema',
                        onTap: () async {
                          final cliente = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CadastrarClienteScreen(),
                            ),
                          );
                          if (cliente != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Cliente ${cliente.nome} cadastrado com sucesso!'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                            // Recarregar estatísticas após adicionar cliente
                            await _carregarEstatisticas();
                          }
                        },
                      ),
                      _buildProfileOption(
                        icon: Icons.person_outline,
                        title: 'Editar Perfil',
                        subtitle: 'Alterar informações pessoais',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _buildProfileOption(
                        icon: Icons.security,
                        title: 'Privacidade e Segurança',
                        subtitle: 'Configurações de conta',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PrivacySecurityScreen(),
                            ),
                          );
                        },
                      ),
                      // _buildProfileOption(
                      //   icon: Icons.payment,
                      //   title: 'Pagamentos',
                      //   subtitle: 'Histórico e métodos de pagamento',
                      //   onTap: () {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //         builder: (context) => const PaymentsScreen(),
                      //       ),
                      //     );
                      //   },
                      // ),
                      _buildProfileOption(
                        icon: Icons.help_outline,
                        title: 'Ajuda e Suporte',
                        subtitle: 'Central de ajuda e contato',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpSupportScreen(),
                            ),
                          );
                        },
                      ),
                      _buildProfileOption(
                        icon: Icons.info_outline,
                        title: 'Sobre o App',
                        subtitle: 'Versão 1.0.0',
                        onTap: () {
                          // Mostrar informações do app
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botão de logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sair da Conta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sair da Conta'),
          content: const Text(
            'Tem certeza que deseja sair da sua conta?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Fazer logout
                await AuthService().logout();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logout realizado com sucesso!'),
                    backgroundColor: Colors.blue,
                  ),
                );

                // Navegar para tela de login
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
  }
}
