import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Tela de abertura do app: logo em destaque e fundo com a mesma lógica de degradê/transparência da página de login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo: gradiente base + imagem hero discreta + overlay (mesma lógica do login)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.darkGreen,
                  AppColors.primary,
                  AppColors.darkGreen,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/hero_login.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.24),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          // Logo maior centralizada
          Center(
            child: Image.asset(
              'assets/logo.png',
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.sports_soccer_rounded,
                  size: 120,
                  color: AppColors.textLight.withOpacity(0.9),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
