import 'package:flutter/material.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidade e Segurança'),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                    Icons.security,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Privacidade e Segurança',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Informações sobre proteção de dados e segurança',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção de Proteção de Dados
            _buildSection(
              title: 'Proteção de Dados',
              icon: Icons.shield,
              children: [
                _buildInfoTile(
                  title: 'Segurança das Informações',
                  subtitle: 'Todos os seus dados de clientes, eventos e pagamentos são criptografados e armazenados com segurança. Utilizamos protocolos de segurança avançados para proteger suas informações.',
                  icon: Icons.lock,
                ),
                _buildInfoTile(
                  title: 'Dados dos Clientes',
                  subtitle: 'As informações dos seus clientes (nome, telefone, endereço, e-mail) são armazenadas de forma segura e utilizadas exclusivamente para gerenciar seus eventos. Nunca compartilhamos dados com terceiros.',
                  icon: Icons.people,
                ),
                _buildInfoTile(
                  title: 'Dados Financeiros',
                  subtitle: 'Suas informações financeiras e de pagamentos são protegidas. Não armazenamos dados de cartão de crédito ou informações bancárias sensíveis.',
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Seção de Privacidade
            _buildSection(
              title: 'Privacidade',
              icon: Icons.privacy_tip,
              children: [
                _buildInfoTile(
                  title: 'Uso dos Dados',
                  subtitle: 'Utilizamos seus dados apenas para fornecer os serviços de gerenciamento de eventos. Seus dados não são vendidos ou compartilhados para fins de marketing.',
                  icon: Icons.info,
                ),
                _buildInfoTile(
                  title: 'Acesso aos Dados',
                  subtitle: 'Apenas você tem acesso completo aos seus dados. Nossa equipe técnica pode acessar dados apenas para suporte técnico, sempre com sua autorização.',
                  icon: Icons.admin_panel_settings,
                ),
                _buildInfoTile(
                  title: 'Backup e Recuperação',
                  subtitle: 'Realizamos backups regulares dos seus dados para garantir que você nunca perca informações importantes sobre seus eventos e clientes.',
                  icon: Icons.backup,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Seção de Conformidade
            _buildSection(
              title: 'Conformidade Legal',
              icon: Icons.gavel,
              children: [
                _buildInfoTile(
                  title: 'LGPD - Lei Geral de Proteção de Dados',
                  subtitle: 'Estamos em conformidade com a LGPD. Você tem direito de acessar, corrigir, excluir ou portar seus dados a qualquer momento.',
                  icon: Icons.verified_user,
                ),
                _buildInfoTile(
                  title: 'Seus Direitos',
                  subtitle: 'Você pode solicitar uma cópia dos seus dados, corrigir informações incorretas, solicitar a exclusão de dados ou portabilidade dos dados para outro serviço.',
                  icon: Icons.assignment,
                ),
                _buildInfoTile(
                  title: 'Contato sobre Privacidade',
                  subtitle: 'Para questões sobre privacidade e proteção de dados, entre em contato através do e-mail: privacidade@festapro.com.br',
                  icon: Icons.email,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
                Icon(icon, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
      ),
      isThreeLine: true,
    );
  }
}
