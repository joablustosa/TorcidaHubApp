import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DigitalCard extends StatelessWidget {
  final FanClubMember member;
  final FanClub fanClub;
  final Profile? profile;
  /// Tipo de assinatura do membro (ex.: "Plano Premium", "Sem assinatura"). Quando null, a linha não é exibida.
  final String? subscriptionType;

  const DigitalCard({
    super.key,
    required this.member,
    required this.fanClub,
    this.profile,
    this.subscriptionType,
  });

  String _getPositionLabel(String position) {
    switch (position) {
      case 'presidente':
        return 'Presidente';
      case 'diretoria':
        return 'Diretoria';
      case 'coordenador':
        return 'Coordenador';
      case 'membro':
        return 'Membro';
      default:
        return position;
    }
  }

  Color _getBadgeColor(String badgeLevel) {
    switch (badgeLevel) {
      case 'bronze':
        return Colors.brown;
      case 'prata':
        return Colors.grey;
      case 'ouro':
        return Colors.amber;
      case 'diamante':
        return Colors.cyan;
      default:
        return AppColors.primary;
    }
  }

  String _getBadgeLabel(String badgeLevel) {
    switch (badgeLevel) {
      case 'bronze':
        return 'Bronze';
      case 'prata':
        return 'Prata';
      case 'ouro':
        return 'Ouro';
      case 'diamante':
        return 'Diamante';
      default:
        return badgeLevel;
    }
  }

  String _generateQRData() {
    return 'torcidahub://member?memberId=${member.id}&fanClubId=${fanClub.id}&registrationNumber=${member.registrationNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.fullName ?? 'Membro';
    final nickname = profile?.nickname;
    final avatarUrl = profile?.avatarUrl;
    final joinDate = member.joinedAt != null
        ? DateFormat('MMM yyyy', 'pt_BR').format(member.joinedAt!)
        : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fanClub.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fanClub.teamName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CARTEIRINHA',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            member.registrationNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Container(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 16,
                    10,
                    isNarrow ? 12 : 16,
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: isNarrow ? _buildNarrowLayout(
                    displayName: displayName,
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    joinDate: joinDate,
                    subscriptionType: subscriptionType,
                  ) : _buildWideLayout(
                    displayName: displayName,
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    joinDate: joinDate,
                    subscriptionType: subscriptionType,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout({
    required String displayName,
    required String? nickname,
    required String? avatarUrl,
    required String joinDate,
    String? subscriptionType,
  }) {
    const double avatarSize = 72;
    // Uma linha: [foto+logo empilhados] | nome+detalhes | QR grande (mesma altura, sem aumentar o card)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatarColumn(displayName: displayName, avatarUrl: avatarUrl, size: avatarSize),
            const SizedBox(height: 4),
            _buildLogoOnly(avatarSize),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMemberInfo(
                displayName: displayName,
                nickname: nickname,
              ),
              const SizedBox(height: 8),
              _buildMemberDetailsVertical(
                joinDate: joinDate,
                subscriptionType: subscriptionType,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildQRSection(size: 110, compact: true),
      ],
    );
  }

  Widget _buildNarrowLayout({
    required String displayName,
    required String? nickname,
    required String? avatarUrl,
    required String joinDate,
    String? subscriptionType,
  }) {
    const double size = 64;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primeira linha: foto + nome/apelido + QR (posição original)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarColumn(
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: size,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMemberInfo(
                displayName: displayName,
                nickname: nickname,
              ),
            ),
            const SizedBox(width: 10),
            _buildQRSection(size: 72, compact: true),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogoOnly(size),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMemberDetailsVertical(
                joinDate: joinDate,
                subscriptionType: subscriptionType,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarColumn({
    required String displayName,
    required String? avatarUrl,
    double size = 96,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  return _avatarPlaceholder(displayName, size);
                },
              )
            : _avatarPlaceholder(displayName, size),
      ),
    );
  }

  /// Apenas o logo da torcida (usado ao lado das informações do membro).
  Widget _buildLogoOnly(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary,
          width: 2,
        ),
        color: Colors.white,
      ),
      child: fanClub.logoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: fanClub.logoUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  return Icon(
                    Icons.shield,
                    size: size * 0.5,
                    color: AppColors.primary,
                  );
                },
              ),
            )
          : Icon(
              Icons.shield,
              size: size * 0.5,
              color: AppColors.primary,
            ),
    );
  }

  Widget _avatarPlaceholder(String displayName, double size) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInfo({
    required String displayName,
    required String? nickname,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (nickname != null && nickname.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '"$nickname"',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// Informações do membro em formato vertical (um dado em cima do outro), ao lado do logo da torcida.
  Widget _buildMemberDetailsVertical({
    required String joinDate,
    String? subscriptionType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.shield, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _getPositionLabel(member.position),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (joinDate.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Membro desde $joinDate',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (subscriptionType != null && subscriptionType.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.card_membership_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Assinatura: $subscriptionType',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getBadgeColor(member.badgeLevel).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getBadgeColor(member.badgeLevel).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: _getBadgeColor(member.badgeLevel)),
                  const SizedBox(width: 4),
                  Text(
                    _getBadgeLabel(member.badgeLevel),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getBadgeColor(member.badgeLevel),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${member.points} pts',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRSection({double size = 120, bool compact = false}) {
    return _QRTapToExpand(
      qrData: _generateQRData(),
      baseSize: size,
      compact: compact,
    );
  }
}

/// QR Code na carteirinha: toque abre overlay em tela cheia (tela escura, QR grande, botão fechar).
class _QRTapToExpand extends StatelessWidget {
  final String qrData;
  final double baseSize;
  final bool compact;

  const _QRTapToExpand({
    required this.qrData,
    this.baseSize = 120,
    this.compact = false,
  });

  void _showFullScreenQR(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => _QRFullScreenOverlay(qrData: qrData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 6.0 : 12.0;
    final spacing = compact ? 2.0 : 6.0;
    return GestureDetector(
      onTap: () => _showFullScreenQR(context),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: baseSize,
              backgroundColor: Colors.white,
            ),
            SizedBox(height: spacing),
            Text(
              'Toque para ampliar',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Validação Digital',
              style: TextStyle(
                fontSize: compact ? 8 : 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay em tela cheia com glass effect: blur + fundo semi-transparente, QR e botão Fechar ao centro.
class _QRFullScreenOverlay extends StatelessWidget {
  final String qrData;

  const _QRFullScreenOverlay({required this.qrData});

  static const double _qrSize = 280;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Glass effect: blur do conteúdo atrás + overlay semi-transparente
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
            // Conteúdo central: card com QR e botão Fechar
            Center(
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {}, // evita fechar ao tocar no card
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 32,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: _qrSize,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Validação Digital',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close_rounded, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Fechar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

