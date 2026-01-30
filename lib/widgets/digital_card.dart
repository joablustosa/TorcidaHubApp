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

  const DigitalCard({
    super.key,
    required this.member,
    required this.fanClub,
    this.profile,
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
                    isNarrow ? 12 : 20,
                    16,
                    isNarrow ? 12 : 20,
                    20,
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
                  ) : _buildWideLayout(
                    displayName: displayName,
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    joinDate: joinDate,
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarColumn(displayName: displayName, avatarUrl: avatarUrl),
        const SizedBox(width: 20),
        Expanded(
          child: _buildMemberInfo(
            displayName: displayName,
            nickname: nickname,
            joinDate: joinDate,
          ),
        ),
        const SizedBox(width: 16),
        _buildQRSection(),
      ],
    );
  }

  Widget _buildNarrowLayout({
    required String displayName,
    required String? nickname,
    required String? avatarUrl,
    required String joinDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarColumn(
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 72,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMemberInfo(
                displayName: displayName,
                nickname: nickname,
                joinDate: joinDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildQRSection(size: 100),
      ],
    );
  }

  Widget _buildAvatarColumn({
    required String displayName,
    required String? avatarUrl,
    double size = 96,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
        const SizedBox(height: 8),
        Container(
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
        ),
      ],
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
    required String joinDate,
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
        const SizedBox(height: 12),
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
              Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Membro desde $joinDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
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
                  Icon(
                    Icons.star,
                    size: 12,
                    color: _getBadgeColor(member.badgeLevel),
                  ),
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
                    style: TextStyle(
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

  Widget _buildQRSection({double size = 120}) {
    return _ZoomableQR(
      qrData: _generateQRData(),
      baseSize: size,
    );
  }
}

/// QR Code que expande com zoom ao toque; toque novamente para remover o zoom.
class _ZoomableQR extends StatefulWidget {
  final String qrData;
  final double baseSize;

  const _ZoomableQR({
    required this.qrData,
    this.baseSize = 120,
  });

  @override
  State<_ZoomableQR> createState() => _ZoomableQRState();
}

class _ZoomableQRState extends State<_ZoomableQR> {
  bool _zoomed = false;

  static const double _zoomScale = 2.0;

  @override
  Widget build(BuildContext context) {
    final size = widget.baseSize;
    return GestureDetector(
      onTap: () {
        setState(() => _zoomed = !_zoomed);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
            AnimatedScale(
              scale: _zoomed ? _zoomScale : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: QrImageView(
                data: widget.qrData,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _zoomed ? 'Toque para reduzir' : 'Toque para ampliar',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Validação Digital',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

