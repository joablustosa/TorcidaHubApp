import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/criar_time_screen.dart';
import '../screens/criar_torcida_screen.dart';
import '../screens/buscar_torcidas_screen.dart';
import '../screens/entrar_torcida_screen.dart';
/// Bottom navigation compartilhado entre Dashboard e as 4 telas de ação.
/// [currentIndex] 0=Criar Time, 1=Buscar, 2=Criar Torcida, 3=Convite. (Perfil acessível pelo avatar no header.)
/// No Dashboard use [currentIndex: 0] para que, ao voltar, nenhum outro fique destacado.
class TorcidaHubBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TorcidaHubBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Navega para a tela do [index]. Se [index] == [currentIndex], não faz nada.
  /// Caso contrário, faz pushReplacement para a tela correspondente.
  static void navigateTo(BuildContext context, int index, int currentIndex) {
    if (index == currentIndex) return;
    final widget = _screenForIndex(index);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget),
    );
  }

  static Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const CriarTimeScreen();
      case 1:
        return const BuscarTorcidasScreen();
      case 2:
        return const CriarTorcidaScreen();
      case 3:
        return const EntrarTorcidaScreen();
      default:
        return const CriarTimeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: currentIndex.clamp(0, 3),
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_soccer),
                label: 'Criar Time',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                label: 'Criar Torcida',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_add),
                label: 'Convite',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
