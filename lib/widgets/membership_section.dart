import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/membership_service.dart';
import '../constants/app_colors.dart';
import 'membership_payment_dialog.dart';
import 'membership_plans_manager.dart';

/// Seção unificada de Assinatura: Minha assinatura + Planos (admin).
/// UX inteligente: TabBar quando admin, conteúdo único quando membro.
class MembershipSection extends StatefulWidget {
  final String fanClubId;
  final String fanClubName;
  final String memberId;
  final bool canManagePlans;

  const MembershipSection({
    super.key,
    required this.fanClubId,
    required this.fanClubName,
    required this.memberId,
    this.canManagePlans = false,
  });

  @override
  State<MembershipSection> createState() => _MembershipSectionState();
}

class _MembershipSectionState extends State<MembershipSection> {
  MemberSubscription? _subscription;
  bool _canReceivePayments = false;
  bool _loading = true;
  bool _recipientLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _recipientLoading = true;
    });

    try {
      final results = await Future.wait([
        MembershipService.getMemberSubscription(widget.memberId),
        MembershipService.canReceivePayments(widget.fanClubId),
      ]);

      if (mounted) {
        setState(() {
          _subscription = results[0] as MemberSubscription?;
          _canReceivePayments = results[1] as bool;
          _loading = false;
          _recipientLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _recipientLoading = false;
          _subscription = null;
        });
      }
    }
  }

  void _showPaymentDialog() {
    // Adia para o próximo frame para evitar Navigator._debugLocked durante o gesto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => MembershipPaymentDialog(
          open: true,
          onOpenChange: (open) {
            if (!open) Navigator.of(ctx).pop();
          },
          fanClubId: widget.fanClubId,
          fanClubName: widget.fanClubName,
          memberId: widget.memberId,
          onPaymentComplete: () {
            Navigator.of(ctx).pop();
            _handlePaymentComplete();
          },
        ),
      );
    });
  }

  void _handlePaymentComplete() {
    _loadData();
  }

  Widget _buildMinhaAssinaturaContent() {
    if (_loading || _recipientLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!_canReceivePayments) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'Planos indisponíveis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A torcida ainda não configurou os planos de assinatura.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isSubscribed =
        _subscription != null && _subscription!.isSubscribed;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSubscribed && _subscription != null)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.success, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Assinatura ativa',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_subscription!.isInGracePeriod)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                'Período de carência',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Você tem acesso aos benefícios exclusivos da torcida',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_subscription!.planName != null)
                        Row(
                          children: [
                            Text(
                              _subscription!.planName!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (_subscription!.planPrice != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'R\$ ${_subscription!.planPrice!.toStringAsFixed(2)}/mês',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (_subscription!.expiresAt != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Válida até ${DateFormat('d \'de\' MMMM \'de\' yyyy', 'pt_BR').format(_subscription!.expiresAt!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => _showPaymentDialog(),
                        icon: const Icon(Icons.workspace_premium, size: 20),
                        label: const Text('Alterar ou renovar plano'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 56,
                        color: AppColors.primary.withOpacity(0.8),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Escolha seu plano',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Assine um plano da ${widget.fanClubName} e tenha acesso a conteúdos exclusivos, descontos na loja e muito mais.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showPaymentDialog(),
                          icon: const Icon(Icons.workspace_premium, size: 22),
                          label: const Text('Ver planos e assinar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textLight,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canManagePlans) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: AppColors.surface,
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.person, size: 20),
                    text: 'Minha assinatura',
                  ),
                  Tab(
                    icon: Icon(Icons.settings, size: 20),
                    text: 'Planos',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMinhaAssinaturaContent(),
                  MembershipPlansManager(fanClubId: widget.fanClubId),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _buildMinhaAssinaturaContent();
  }
}
