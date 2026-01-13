import 'package:flutter/material.dart';
import '../../models/api_models.dart';
import '../../services/cliente_service.dart';

class CadastrarClienteScreen extends StatefulWidget {
  const CadastrarClienteScreen({super.key});

  @override
  State<CadastrarClienteScreen> createState() => _CadastrarClienteScreenState();
}

class _CadastrarClienteScreenState extends State<CadastrarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _telefoneController = TextEditingController();

  final ClienteService _clienteService = ClienteService();
  List<UserApi> _clientes = [];
  bool _isLoading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _clienteService.initialize();
      await _refreshClientes();
    } catch (e) {
      print('Erro ao inicializar dados: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshClientes() async {
    try {
      final clientes = await _clienteService.getClientesApi();
      setState(() {
        _clientes = clientes;
      });
    } catch (e) {
      print('Erro ao buscar clientes: $e');
    }
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Separar nome em firstName e lastName
        final nomeParts = _nomeController.text.trim().split(' ');
        final firstName = nomeParts.isNotEmpty ? nomeParts[0] : '';
        final lastName =
            nomeParts.length > 1 ? nomeParts.sublist(1).join(' ') : '';

        final userApi = UserApi(
          id: 0,
          usuarioLogin: _emailController.text.trim(), // Login será o email
          chaveDeAcesso: '', // Não será definido no cadastro
          firstName: firstName,
          lastName: lastName.isNotEmpty ? lastName : null,
          email: _emailController.text.trim(),
          contact: _telefoneController.text.trim(),
          address: _enderecoController.text.trim(),
          userType: 2, // Cliente
          status: 1, // Ativo
          userStatus: 1,
        );

        final novoCliente = await _clienteService.createCliente(userApi);
        if (novoCliente != null) {
          // Limpar formulário
          _formKey.currentState!.reset();
          _nomeController.clear();
          _emailController.clear();
          _enderecoController.clear();
          _telefoneController.clear();

          // Atualizar lista
          await _refreshClientes();

          // Mostrar sucesso
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cliente cadastrado com sucesso!'),
                backgroundColor: Colors.blue,
              ),
            );
          }

          // Voltar para visualização da lista
          setState(() {
            _showForm = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao cadastrar cliente: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Clientes'),
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
              // Navega de volta para a agenda principal
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'Voltar à Agenda',
          ),
          IconButton(
            icon: Icon(_showForm ? Icons.list : Icons.add),
            onPressed: () {
              setState(() {
                _showForm = !_showForm;
              });
            },
            tooltip: _showForm ? 'Ver Lista' : 'Adicionar Cliente',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showForm
              ? _buildForm()
              : _buildClientesList(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Novo Cliente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Preencha as informações do cliente',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Campo Nome
            _buildTextField(
              controller: _nomeController,
              label: 'Nome Completo',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o nome do cliente';
                }
                if (value.length < 3) {
                  return 'O nome deve ter pelo menos 3 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Campo Email
            _buildTextField(
              controller: _emailController,
              label: 'E-mail',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o e-mail do cliente';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Por favor, insira um e-mail válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Campo Endereço
            _buildTextField(
              controller: _enderecoController,
              label: 'Endereço',
              icon: Icons.location_on,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o endereço do cliente';
                }
                if (value.length < 10) {
                  return 'O endereço deve ter pelo menos 10 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Campo Telefone
            _buildTextField(
              controller: _telefoneController,
              label: 'Telefone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o telefone do cliente';
                }
                if (value.length < 10) {
                  return 'O telefone deve ter pelo menos 10 dígitos';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Botões
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salvarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Salvar Cliente'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientesList() {
    return Column(
      children: [
        // Header da lista
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.people,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Clientes Cadastrados',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${_clientes.length} clientes',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Lista de clientes
        Expanded(
          child: _clientes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum cliente cadastrado',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Toque no botão + para adicionar um cliente',
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
                  itemCount: _clientes.length,
                  itemBuilder: (context, index) {
                    final cliente = _clientes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            cliente.nomeCompleto.isNotEmpty
                                ? cliente.nomeCompleto[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          cliente.nomeCompleto,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cliente.email != null &&
                                cliente.email!.isNotEmpty)
                              Text(cliente.email!),
                            if (cliente.contact != null &&
                                cliente.contact!.isNotEmpty)
                              Text(cliente.contact!),
                            if (cliente.address != null &&
                                cliente.address!.isNotEmpty)
                              Text(
                                cliente.address!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              // Implementar edição
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar Exclusão'),
                                  content: Text(
                                      'Deseja realmente excluir o cliente "${cliente.nomeCompleto}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                // Atualizar status para 0 (inativo) ao invés de deletar
                                final clienteAtualizado = UserApi(
                                  id: cliente.id,
                                  usuarioLogin: cliente.usuarioLogin,
                                  firstName: cliente.firstName,
                                  lastName: cliente.lastName,
                                  email: cliente.email,
                                  contact: cliente.contact,
                                  address: cliente.address,
                                  userType: cliente.userType,
                                  status: 0, // Inativo
                                  userStatus: 0,
                                  id_enterprise: cliente.id_enterprise,
                                  tenant_id: cliente.tenant_id,
                                );
                                final resultado =
                                    await _clienteService.updateCliente(
                                        cliente.id, clienteAtualizado);
                                if (resultado != null) {
                                  await _refreshClientes();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Cliente excluído com sucesso!'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }
}
