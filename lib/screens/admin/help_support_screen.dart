import 'package:flutter/material.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'Como adicionar um novo evento?',
      answer: 'Toque no botão "+" no centro da navegação inferior e preencha os dados solicitados: cliente, endereço, valor, data e hora de início e fim do evento.',
    ),
    FAQItem(
      question: 'Como gerenciar os pagamentos de um evento?',
      answer: 'Na tela de detalhes do dia, toque em um evento para abrir a página de pagamentos. Lá você pode adicionar pagamentos parciais e acompanhar o progresso do pagamento total.',
    ),
    FAQItem(
      question: 'Como cadastrar um novo cliente?',
      answer: 'Acesse a tela de "Gerenciar Clientes" através do menu e toque no botão "+" para adicionar um novo cliente com nome, e-mail, telefone e endereço.',
    ),
    FAQItem(
      question: 'Como visualizar o histórico de pagamentos?',
      answer: 'Acesse a aba "Pagamentos" na navegação inferior para ver todos os eventos com pagamentos confirmados e o histórico financeiro.',
    ),
    FAQItem(
      question: 'O app funciona para diferentes tipos de eventos?',
      answer: 'Sim! O Agenda De Festas é ideal para empreendedores de eventos como buffet, estações de pipoca, open bar, fotografia, decoração e outros serviços de eventos.',
    ),
    FAQItem(
      question: 'Como acompanhar o progresso de pagamento de um evento?',
      answer: 'Ao abrir a página de pagamentos de um evento, você verá uma barra de progresso mostrando quanto já foi pago em relação ao valor total do evento.',
    ),
    FAQItem(
      question: 'Posso adicionar múltiplos pagamentos para o mesmo evento?',
      answer: 'Sim! Você pode adicionar quantos pagamentos forem necessários para um evento, permitindo registrar pagamentos parciais, entrada, parcelas, etc.',
    ),
    FAQItem(
      question: 'O app funciona offline?',
      answer: 'Sim! O app funciona offline para visualização e criação de eventos. Os dados são sincronizados automaticamente quando há conexão com a internet.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda e Suporte'),
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
                    Icons.help_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Como podemos ajudar?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Encontre respostas para suas dúvidas ou entre em contato conosco',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Contato direto
            Container(
              width: double.infinity,
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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.contact_support, color: Colors.blue),
                        SizedBox(width: 12),
                        Text(
                          'Contato Direto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildContactOption(
                    'Chat ao Vivo',
                    'Fale diretamente com nosso suporte',
                    Icons.chat,
                    () => _showContactDialog('Chat ao Vivo'),
                  ),
                  _buildContactOption(
                    'E-mail',
                    'suporte@festapro.com.br',
                    Icons.email,
                    () => _showContactDialog('E-mail'),
                  ),
                  _buildContactOption(
                    'WhatsApp',
                    'Entre em contato via WhatsApp',
                    Icons.chat,
                    () => _showContactDialog('WhatsApp'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // FAQ
            Container(
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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.question_answer, color: Colors.blue),
                        SizedBox(width: 12),
                        Text(
                          'Perguntas Frequentes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._faqItems.map((faq) => _buildFAQItem(faq)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Tutoriais
            Container(
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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Text(
                          'Tutoriais em Vídeo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTutorialItem(
                    'Primeiros Passos',
                    'Aprenda a usar o app para gerenciar seus eventos',
                    '5:30',
                    Icons.play_arrow,
                  ),
                  _buildTutorialItem(
                    'Gerenciando Clientes',
                    'Como cadastrar e organizar seus clientes',
                    '6:20',
                    Icons.play_arrow,
                  ),
                  _buildTutorialItem(
                    'Controle de Pagamentos',
                    'Como registrar e acompanhar pagamentos dos eventos',
                    '7:15',
                    Icons.play_arrow,
                  ),
                  _buildTutorialItem(
                    'Dashboard Financeiro',
                    'Entenda como usar o dashboard para acompanhar suas finanças',
                    '5:45',
                    Icons.play_arrow,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botão de feedback
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFeedbackDialog(),
                icon: const Icon(Icons.feedback),
                label: const Text('Enviar Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildFAQItem(FAQItem faq) {
    return ExpansionTile(
      leading: const Icon(Icons.help_outline, color: Colors.blue),
      title: Text(
        faq.question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            faq.answer,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialItem(String title, String subtitle, String duration, IconData icon) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            duration,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const Icon(Icons.play_circle_outline, color: Colors.blue),
        ],
      ),
      onTap: () => _showTutorialDialog(title),
    );
  }

  void _showContactDialog(String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contato via $method'),
        content: Text('Funcionalidade em desenvolvimento. Em breve você poderá entrar em contato via $method.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTutorialDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tutorial: $title'),
        content: const Text('Funcionalidade em desenvolvimento. Em breve você poderá assistir aos tutoriais em vídeo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Feedback'),
        content: const Text('Funcionalidade em desenvolvimento. Em breve você poderá enviar feedback diretamente pelo app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}
