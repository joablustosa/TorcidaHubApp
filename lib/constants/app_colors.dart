import 'package:flutter/material.dart';

class AppColors {
  // Cores principais baseadas no logo Torcida Hub
  // Verde escuro (dark green) - borda externa e fundo do escudo
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32); // Verde médio
  static const Color lightGreen = Color(0xFF66BB6A); // Verde claro
  static const Color neonGreen = Color(0xFF4CAF50); // Verde neon dos holofotes
  
  // Azul do texto "HUB"
  static const Color hubBlue = Color(0xFF2196F3);
  static const Color blueAccent = Color(0xFF42A5F5);
  
  // Vermelho da seta
  static const Color accentRed = Color(0xFFE53935);
  
  // Cores neutras
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [darkGreen, primary, lightGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient heroGradient = LinearGradient(
    colors: [darkGreen, primary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Cores de estado
  static const Color success = lightGreen;
  static const Color error = accentRed;
  static const Color warning = Color(0xFFFF9800);
  static const Color info = hubBlue;
  
  // Cores de texto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Colors.white;
  static const Color textLightSecondary = Color(0xFFE0E0E0);
  
  // Cores de fundo
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Sombras
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  // Bordas arredondadas
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius buttonBorderRadius = BorderRadius.all(Radius.circular(8));
}

class AppStyles {
  // Textos
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.textLight,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.textLightSecondary,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );
  
  // Espaçamentos
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Tamanhos de ícones
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
}
