import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/membership_service.dart' show MembershipAccessConfig, MembershipService;
import '../constants/app_colors.dart';

/// Configurações de acesso para membros pagantes (admin).
class MembershipAccessSettings extends StatefulWidget {
  final String fanClubId;
  final bool requiresMembership;

  const MembershipAccessSettings({
    super.key,
    required this.fanClubId,
    this.requiresMembership = false,
  });

  @override
  State<MembershipAccessSettings> createState() =>
      _MembershipAccessSettingsState();
}

class _MembershipAccessSettingsState extends State<MembershipAccessSettings> {
  late MembershipAccessSettingsData _settings;
  int _gracePeriodDays = 7;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final access = await MembershipService.getAccessSettings(widget.fanClubId);
      final grace =
          await MembershipService.getGracePeriodDays(widget.fanClubId);
      if (mounted) {
        setState(() {
          _settings = MembershipAccessSettingsData(
            requiresMembership: access.requiresMembership,
            postsExclusive: access.settings.postsExclusive,
            eventsExclusive: access.settings.eventsExclusive,
            storeDiscount: access.settings.storeDiscount,
            rankingExclusive: access.settings.rankingExclusive,
            albumsExclusive: access.settings.albumsExclusive,
            defaultMemberDiscount: access.settings.defaultMemberDiscount,
          );
          _gracePeriodDays = grace;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _settings = MembershipAccessSettingsData();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await MembershipService.saveAccessSettings(
        fanClubId: widget.fanClubId,
        requiresMembership: widget.requiresMembership,
        settings: MembershipAccessConfig(
          postsExclusive: _settings.postsExclusive,
          eventsExclusive: _settings.eventsExclusive,
          storeDiscount: _settings.storeDiscount,
          rankingExclusive: _settings.rankingExclusive,
          albumsExclusive: _settings.albumsExclusive,
          defaultMemberDiscount: _settings.defaultMemberDiscount,
        ),
        gracePeriodDays: _gracePeriodDays,
      );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configurações salvas!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSettingRow(
          icon: Icons.article_outlined,
          iconColor: AppColors.info,
          title: 'Posts exclusivos',
          subtitle: 'Permitir criar posts visíveis apenas para pagantes',
          value: _settings.postsExclusive,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(postsExclusive: v)),
        ),
        _buildSettingRow(
          icon: Icons.event,
          iconColor: AppColors.success,
          title: 'Eventos exclusivos',
          subtitle: 'Eventos que só pagantes podem participar',
          value: _settings.eventsExclusive,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(eventsExclusive: v)),
        ),
        _buildSettingRow(
          icon: Icons.shopping_bag_outlined,
          iconColor: AppColors.warning,
          title: 'Desconto na loja',
          subtitle: 'Pagantes recebem desconto em produtos',
          value: _settings.storeDiscount,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(storeDiscount: v)),
          trailing: _settings.storeDiscount
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 70),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextFormField(
                          initialValue: _settings.defaultMemberDiscount.toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 0 && n <= 100) {
                              setState(() => _settings =
                                  _settings.copyWith(defaultMemberDiscount: n));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('%'),
                    ],
                  ),
                )
              : null,
        ),
        _buildSettingRow(
          icon: Icons.emoji_events_outlined,
          iconColor: AppColors.warning,
          title: 'Ranking exclusivo',
          subtitle: 'Apenas pagantes participam do ranking',
          value: _settings.rankingExclusive,
          onChanged: (v) => setState(
              () => _settings = _settings.copyWith(rankingExclusive: v)),
        ),
        _buildSettingRow(
          icon: Icons.photo_library_outlined,
          iconColor: AppColors.primary,
          title: 'Álbuns exclusivos',
          subtitle: 'Restringir acesso a álbuns para pagantes',
          value: _settings.albumsExclusive,
          onChanged: (v) => setState(
              () => _settings = _settings.copyWith(albumsExclusive: v)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.schedule, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Período de carência (dias)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: _gracePeriodDays.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 0 && n <= 30) {
                    setState(() => _gracePeriodDays = n);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save, size: 20),
            label: Text(_saving ? 'Salvando...' : 'Salvar configurações'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 8),
          ],
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Dados editáveis das configurações de acesso.
class MembershipAccessSettingsData {
  final bool requiresMembership;
  final bool postsExclusive;
  final bool eventsExclusive;
  final bool storeDiscount;
  final bool rankingExclusive;
  final bool albumsExclusive;
  final int defaultMemberDiscount;

  MembershipAccessSettingsData({
    this.requiresMembership = false,
    this.postsExclusive = true,
    this.eventsExclusive = true,
    this.storeDiscount = true,
    this.rankingExclusive = false,
    this.albumsExclusive = false,
    this.defaultMemberDiscount = 10,
  });

  MembershipAccessSettingsData copyWith({
    bool? requiresMembership,
    bool? postsExclusive,
    bool? eventsExclusive,
    bool? storeDiscount,
    bool? rankingExclusive,
    bool? albumsExclusive,
    int? defaultMemberDiscount,
  }) {
    return MembershipAccessSettingsData(
      requiresMembership: requiresMembership ?? this.requiresMembership,
      postsExclusive: postsExclusive ?? this.postsExclusive,
      eventsExclusive: eventsExclusive ?? this.eventsExclusive,
      storeDiscount: storeDiscount ?? this.storeDiscount,
      rankingExclusive: rankingExclusive ?? this.rankingExclusive,
      albumsExclusive: albumsExclusive ?? this.albumsExclusive,
      defaultMemberDiscount:
          defaultMemberDiscount ?? this.defaultMemberDiscount,
    );
  }
}
