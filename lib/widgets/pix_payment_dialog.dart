import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/supabase_service.dart';

class PixPaymentDialog extends StatefulWidget {
  final String orderId;
  final String qrCode;
  final String? qrCodeUrl;
  final DateTime expiresAt;
  final double baseAmount;
  final double fee;
  final double total;
  final String itemName;
  final VoidCallback? onPaymentConfirmed;

  const PixPaymentDialog({
    super.key,
    required this.orderId,
    required this.qrCode,
    this.qrCodeUrl,
    required this.expiresAt,
    required this.baseAmount,
    required this.fee,
    required this.total,
    required this.itemName,
    this.onPaymentConfirmed,
  });

  @override
  State<PixPaymentDialog> createState() => _PixPaymentDialogState();
}

class _PixPaymentDialogState extends State<PixPaymentDialog> {
  bool _copied = false;
  bool _checking = false;
  String _timeLeft = '';
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _updateTimer();
    _startTimer();
    _startPaymentCheck();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateTimer();
        if (!_expired) {
          _startTimer();
        }
      }
    });
  }

  void _updateTimer() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);

    if (diff.isNegative) {
      setState(() {
        _expired = true;
        _timeLeft = 'Expirado';
      });
      return;
    }

    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    setState(() {
      _timeLeft = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    });
  }

  void _startPaymentCheck() {
    if (_expired) return;

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted || _expired) return;

      setState(() {
        _checking = true;
      });

      try {
        final response = await SupabaseService.client
            .from('payment_transactions')
            .select('status')
            .eq('pagarme_order_id', widget.orderId)
            .maybeSingle();

        if (response != null) {
          final status = response['status'] as String?;
          if (status == 'paid') {
            widget.onPaymentConfirmed?.call();
            if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }
        }
      } catch (e) {
        print('Erro ao verificar pagamento: $e');
      } finally {
        if (mounted) {
          setState(() {
            _checking = false;
          });
          if (!_expired) {
            _startPaymentCheck();
          }
        }
      }
    });
  }

  Future<void> _copyPixCode() async {
    await Clipboard.setData(ClipboardData(text: widget.qrCode));
    setState(() {
      _copied = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código PIX copiado!'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Row(
              children: [
                const Icon(Icons.qr_code, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pagamento via PIX',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.itemName,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Conteúdo
            if (_expired)
              Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Código expirado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O código PIX expirou. Por favor, tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  // Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Expira em: $_timeLeft',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.2),
                      ),
                    ),
                    child: widget.qrCodeUrl != null
                        ? Image.network(
                            widget.qrCodeUrl!,
                            width: 200,
                            height: 200,
                          )
                        : QrImageView(
                            data: widget.qrCode,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 24),
                  // Código PIX
                  const Text(
                    'Ou copie o código PIX abaixo:',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      widget.qrCode,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _copyPixCode,
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(_copied ? 'Copiado!' : 'Copiar código PIX'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Valores
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Valor do item:'),
                            Text('R\$ ${NumberFormat('#,##0.00').format(widget.baseAmount)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Taxa de conveniência (4,99%):',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'R\$ ${NumberFormat('#,##0.00').format(widget.fee)}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total a pagar:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'R\$ ${NumberFormat('#,##0.00').format(widget.total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_checking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'Aguardando pagamento...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
    );
  }
}

