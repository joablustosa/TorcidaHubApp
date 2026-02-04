import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/store_service.dart';
import '../constants/app_colors.dart';
import 'pix_payment_dialog.dart';

class ProductCheckoutDialog extends StatefulWidget {
  final bool open;
  final ValueChanged<bool> onOpenChange;
  final List<CartItem> cart;
  final String fanClubId;
  final VoidCallback onSuccess;

  const ProductCheckoutDialog({
    super.key,
    required this.open,
    required this.onOpenChange,
    required this.cart,
    required this.fanClubId,
    required this.onSuccess,
  });

  @override
  State<ProductCheckoutDialog> createState() => _ProductCheckoutDialogState();
}

class _ProductCheckoutDialogState extends State<ProductCheckoutDialog> {
  bool _loading = false;
  String _deliveryMethod = 'pickup';
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  bool _canReceivePayments = false;
  bool _recipientLoading = true;

  static const double _platformFeePercent = 5;
  static const double _gatewayFeeFixed = 0.85;
  static const double _withdrawalFeeReais = 1;

  @override
  void initState() {
    super.initState();
    _checkRecipient();
    if (widget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCheckoutDialog());
    }
  }

  Future<void> _checkRecipient() async {
    setState(() => _recipientLoading = true);
    try {
      final canReceive =
          await StoreService.canReceivePayments(widget.fanClubId);
      if (mounted) {
        setState(() {
          _canReceivePayments = canReceive;
          _recipientLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _canReceivePayments = false;
          _recipientLoading = false;
        });
      }
    }
  }

  double get _subtotal {
    return widget.cart.fold(
        0, (sum, item) => sum + item.discountedUnitPrice * item.quantity);
  }

  double get _platformFee =>
      (_subtotal * _platformFeePercent / 100).roundToDouble() / 100;

  double get _total =>
      _subtotal + _platformFee + _gatewayFeeFixed + _withdrawalFeeReais;

  bool get _deliveryAvailable =>
      widget.cart.any((item) => item.product.deliveryAvailable);

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) {
      return digits.isEmpty ? '' : '($digits';
    }
    if (digits.length <= 7) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout(BuildContext dialogContext) async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu telefone para contato'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_deliveryMethod == 'delivery') {
      final addr = _addressController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      if (addr.isEmpty || city.isEmpty || state.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha o endereço de entrega'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final items = widget.cart.map((item) {
        return {
          'product_id': item.product.id,
          'variant_id': item.variant?.id,
          'product_name': item.product.name,
          'variant_name': item.variant?.name,
          'quantity': item.quantity,
          'unit_price': item.discountedUnitPrice,
        };
      }).toList();

      final response = await StoreService.createWooviStorePayment(
        fanClubId: widget.fanClubId,
        items: items,
        deliveryMethod: _deliveryMethod,
        deliveryAddress:
            _deliveryMethod == 'delivery' ? _addressController.text.trim() : null,
        deliveryCity:
            _deliveryMethod == 'delivery' ? _cityController.text.trim() : null,
        deliveryState:
            _deliveryMethod == 'delivery' ? _stateController.text.trim() : null,
        deliveryZip:
            _deliveryMethod == 'delivery' ? _zipController.text.trim() : null,
        customerPhone: _phoneController.text.trim(),
        customerNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (response == null) throw Exception('Resposta vazia');

      final pix = response['pix'] as Map<String, dynamic>?;
      if (pix == null || pix['qr_code'] == null) {
        throw Exception('Dados PIX não retornados');
      }

      // Woovi retorna order_id (correlationID) - usado para polling em payment_transactions.pagarme_order_id
      final orderId = response['order_id'] as String?;
      if (orderId == null) {
        throw Exception('ID do pedido não retornado');
      }

      final expiresAtStr = pix['expires_at'] as String?;
      final expiresAt = expiresAtStr != null
          ? DateTime.parse(expiresAtStr)
          : DateTime.now().add(const Duration(hours: 2));

      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(dialogContext).pop();
        final totalAmount =
            (response['amount'] as num?)?.toDouble() ?? _total;
        final qrCode = pix['qr_code'] as String;
        final qrCodeUrl = pix['qr_code_url'] as String?;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PixPaymentDialog(
            orderId: orderId,
            qrCode: qrCode,
            qrCodeUrl: qrCodeUrl,
            expiresAt: expiresAt,
            baseAmount: _subtotal,
            fee: _platformFee,
            total: totalAmount,
            itemName: 'Pedido da Loja',
            onPaymentConfirmed: () {
              Navigator.of(ctx).pop();
              _handlePixSuccess();
            },
          ),
        );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handlePixSuccess() {
    widget.onSuccess();
    widget.onOpenChange(false);
  }

  @override
  void didUpdateWidget(ProductCheckoutDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) _showCheckoutDialog();
      });
    }
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: _buildCheckoutContent(ctx),
      ),
    ).then((_) => widget.onOpenChange(false));
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildCheckoutContent(BuildContext ctx) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Finalizar Compra',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!_canReceivePayments && !_recipientLoading)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esta torcida ainda não pode receber pagamentos. O recebedor precisa ser configurado e aprovado.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text('Resumo do Pedido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ...widget.cart.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.product.name}${item.variant != null ? ' (${item.variant!.name})' : ''} x${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'R\$ ${(item.discountedUnitPrice * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      _buildSummaryRow('Subtotal', _subtotal),
                      _buildSummaryRow(
                        'Taxa de conveniência ($_platformFeePercent%)',
                        _platformFee,
                        muted: true,
                      ),
                      _buildSummaryRow(
                        'Taxa de transação',
                        _gatewayFeeFixed,
                        muted: true,
                      ),
                      _buildSummaryRow(
                        'Taxa de saque',
                        _withdrawalFeeReais,
                        muted: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'R\$ ${_total.toStringAsFixed(2)}',
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
                const Text('Método de Entrega',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'pickup',
                  groupValue: _deliveryMethod,
                  onChanged: (v) => setState(() => _deliveryMethod = v!),
                  title: const Text('Retirar no local'),
                  secondary: const Icon(Icons.location_on),
                ),
                if (_deliveryAvailable)
                  RadioListTile<String>(
                    value: 'delivery',
                    groupValue: _deliveryMethod,
                    onChanged: (v) => setState(() => _deliveryMethod = v!),
                    title: const Text('Entrega (combinar com a torcida)'),
                    secondary: const Icon(Icons.local_shipping),
                  ),
                const SizedBox(height: 20),
                if (_deliveryMethod == 'delivery') ...[
                  const Text('Endereço de Entrega',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Endereço completo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            hintText: 'Cidade',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _stateController,
                          decoration: InputDecoration(
                            hintText: 'Estado',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _zipController,
                    decoration: InputDecoration(
                      hintText: 'CEP',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                ],
                const Text('Telefone para contato *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: '(11) 99999-9999',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final formatted = _formatPhone(newValue.text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Observações (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Alguma observação sobre o pedido?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_loading || !_canReceivePayments || _recipientLoading)
                        ? null
                        : () => _handleCheckout(ctx),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            !_canReceivePayments
                                ? 'Pagamentos indisponíveis'
                                : 'Pagar R\$ ${_total.toStringAsFixed(2)} via PIX',
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
                const SizedBox(height: 12),
                Text(
                  _deliveryMethod == 'delivery'
                      ? 'A torcida entrará em contato para combinar a entrega após a confirmação do pagamento.'
                      : 'Após a confirmação do pagamento, você será notificado sobre a retirada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'R\$ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              fontWeight: muted ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
