import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/membership_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../constants/app_colors.dart';
import 'pix_payment_dialog.dart';

const double _platformFeePercent = 5;
const double _gatewayFeeFixed = 0.85;
const double _withdrawalFeeReais = 1;

class MembershipPaymentDialog extends StatefulWidget {
  final bool open;
  final ValueChanged<bool> onOpenChange;
  final String fanClubId;
  final String fanClubName;
  final String memberId;
  final VoidCallback onPaymentComplete;

  const MembershipPaymentDialog({
    super.key,
    required this.open,
    required this.onOpenChange,
    required this.fanClubId,
    required this.fanClubName,
    required this.memberId,
    required this.onPaymentComplete,
  });

  @override
  State<MembershipPaymentDialog> createState() => _MembershipPaymentDialogState();
}

class _MembershipPaymentDialogState extends State<MembershipPaymentDialog> {
  final _authService = AuthServiceSupabase();
  List<MembershipPlan> _plans = [];
  MembershipPlan? _selectedPlan;
  bool _loading = true;
  bool _processing = false;
  Map<String, dynamic>? _pixData;
  String? _profileName;
  String? _profilePhone;
  String? _profileCpf;

  static const Map<String, String> _billingLabels = {
    'monthly': 'mês',
    'quarterly': 'trimestre',
    'yearly': 'ano',
  };

  @override
  void initState() {
    super.initState();
    if (widget.open) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!widget.open) return;

    setState(() => _loading = true);
    try {
      final plans =
          await MembershipService.getPlans(widget.fanClubId);

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone, cpf')
          .eq('id', _authService.userId!)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _plans = plans;
          _selectedPlan =
              plans.cast<MembershipPlan?>().firstWhere(
                    (p) => p?.isDefault ?? false,
                    orElse: () => plans.isNotEmpty ? plans.first : null,
                  );
          _profileName = profile?['full_name'] as String? ?? '';
          _profilePhone = profile?['phone'] as String?;
          _profileCpf = profile?['cpf'] as String?;
          _loading = false;
          _pixData = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _plans = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar planos: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double _calculateFee(double price) {
    final fee = price * (_platformFeePercent / 100);
    return price + fee + _gatewayFeeFixed + _withdrawalFeeReais;
  }

  @override
  void didUpdateWidget(MembershipPaymentDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _loadData();
    }
  }

  Future<void> _handleCreatePayment() async {
    if (_selectedPlan == null) return;
    if ((_profileName ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha seu nome no perfil'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final data = await MembershipService.createMembershipPayment(
        fanClubId: widget.fanClubId,
        memberId: widget.memberId,
        planId: _selectedPlan!.id,
        customerName: _profileName!.trim(),
        customerEmail: _authService.userEmail ?? '',
        customerPhone: _profilePhone?.trim(),
        customerCpf: _profileCpf?.trim(),
      );

      if (mounted) {
        setState(() {
          _processing = false;
          _pixData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPixDialog() {
    if (_pixData == null) return;
    // payment_id (correlationID) é usado para polling em payment_transactions.pagarme_order_id
    final orderId = (_pixData!['payment_id'] ?? _pixData!['qr_code'] ?? '').toString();
    final qrCode = _pixData!['qr_code'] as String? ?? '';
    final qrCodeImage = _pixData!['qr_code_image'] as String?;
    final amount = (_pixData!['amount'] as num?)?.toDouble() ?? 0.0;
    final baseAmount = (_pixData!['base_amount'] as num?)?.toDouble() ?? 0.0;
    final platformFee =
        (_pixData!['platform_fee'] as num?)?.toDouble() ?? 0.0;
    final expiresAtStr = _pixData!['expires_at'] as String?;
    final expiresAt = expiresAtStr != null
        ? DateTime.parse(expiresAtStr)
        : DateTime.now().add(const Duration(hours: 1));

    final nav = Navigator.of(context);
    final overlayContext = nav.overlay?.context ?? context;
    nav.pop();
    showDialog(
      context: overlayContext,
      barrierDismissible: false,
      builder: (ctx) => PixPaymentDialog(
        orderId: orderId,
        qrCode: qrCode,
        qrCodeUrl: qrCodeImage,
        expiresAt: expiresAt,
        baseAmount: baseAmount,
        fee: platformFee,
        total: amount,
        itemName: 'Assinatura ${_selectedPlan?.name ?? ''}',
        onPaymentConfirmed: () {
          Navigator.of(ctx).pop();
          widget.onPaymentComplete();
          widget.onOpenChange(false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    if (_pixData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pixData != null) _showPixDialog();
      });
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Assinar Plano',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => widget.onOpenChange(false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (_plans.isEmpty)
                  Column(
                    children: [
                      Icon(Icons.info_outline,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum plano disponível',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => widget.onOpenChange(false),
                        child: const Text('Fechar'),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    'Escolha um plano para se tornar membro pagante de ${widget.fanClubName}:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_plans.length, (i) {
                    final plan = _plans[i];
                    final isSelected = _selectedPlan?.id == plan.id;
                    final total = _calculateFee(plan.price);
                    return InkWell(
                      onTap: () => setState(() => _selectedPlan = plan),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<MembershipPlan>(
                              value: plan,
                              groupValue: _selectedPlan,
                              onChanged: (p) => setState(() => _selectedPlan = p),
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          plan.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (plan.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Recomendado',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (plan.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.description!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (plan.benefits.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...plan.benefits.take(3).map((b) => Row(
                                          children: [
                                            Icon(Icons.check,
                                                size: 14,
                                                color: AppColors.success),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                b,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )),
                                  ],
                                ],
                              ),
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'R\$ ${plan.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '/${_billingLabels[plan.billingPeriod] ?? plan.billingPeriod}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Total: R\$ ${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_selectedPlan != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildFeeRow(
                            'Plano ${_selectedPlan!.name}:',
                            _selectedPlan!.price,
                          ),
                          _buildFeeRow(
                            'Taxa de serviço ($_platformFeePercent%):',
                            _selectedPlan!.price *
                                (_platformFeePercent / 100),
                            muted: true,
                          ),
                          _buildFeeRow(
                            'Taxa de transação:',
                            _gatewayFeeFixed + _withdrawalFeeReais,
                            muted: true,
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'R\$ ${_calculateFee(_selectedPlan!.price).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _handleCreatePayment,
                        icon: _processing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.qr_code),
                        label: Text(
                          _processing ? 'Gerando PIX...' : 'Gerar PIX',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textLight,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, double value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
          Text(
            'R\$ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
