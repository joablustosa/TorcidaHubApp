import '../services/supabase_service.dart';

class PermissionsService {
  static Future<Map<String, bool>> getPermissions({
    required String fanClubId,
    required String positionName,
  }) async {
    try {
      // Presidente e diretoria sempre têm todas as permissões
      if (positionName == 'presidente' || positionName == 'diretoria') {
        return _getAllPermissions();
      }

      final response = await SupabaseService.client
          .from('fan_club_positions')
          .select('permissions')
          .eq('fan_club_id', fanClubId)
          .eq('name', _capitalizeFirst(positionName))
          .maybeSingle();

      if (response != null) {
        final permissions = response['permissions'];
        if (permissions is Map) {
          return Map<String, bool>.from(permissions);
        }
      }

      return {};
    } catch (e) {
      print('Erro ao buscar permissões: $e');
      return {};
    }
  }

  static bool hasPermission({
    required String positionName,
    required Map<String, bool> permissions,
    required String permissionKey,
  }) {
    // Presidente sempre tem todas as permissões
    if (positionName == 'presidente') {
      return true;
    }

    // Diretoria tem todas as permissões por padrão (legacy)
    if (positionName == 'diretoria') {
      // Se permissões específicas estão definidas, use-as; caso contrário, padrão é true
      if (permissions.isEmpty) {
        return true;
      }
      return permissions[permissionKey] == true;
    }

    // Para outras posições, verificar permissão específica
    return permissions[permissionKey] == true;
  }

  static bool isAdmin(String positionName) {
    return positionName == 'presidente' || positionName == 'diretoria';
  }

  static Map<String, bool> _getAllPermissions() {
    return {
      'criar_publicacoes': true,
      'editar_publicacoes': true,
      'deletar_publicacoes': true,
      'fixar_publicacoes': true,
      'moderar_comentarios': true,
      'criar_eventos': true,
      'editar_eventos': true,
      'deletar_eventos': true,
      'gerenciar_eventos': true,
      'criar_albuns': true,
      'editar_albuns': true,
      'deletar_albuns': true,
      'adicionar_fotos': true,
      'remover_fotos': true,
      'gerenciar_membros': true,
      'editar_torcida': true,
      'configuracoes': true,
      'manage_membership_plans': true,
    };
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

