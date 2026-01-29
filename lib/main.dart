import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/minha_torcida_screen.dart';
import 'services/auth_service_supabase.dart';
import 'services/supabase_service.dart';
import 'constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeDateFormatting('pt_BR', null);
    
    // Inicializar Supabase
    await SupabaseService.initialize();
    
    // Inicializar AuthService
    final authService = AuthServiceSupabase();
    await authService.initialize();
    
    runApp(TorcidaHubApp(authService: authService));
  } catch (e) {
    print('Erro ao inicializar app: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Erro ao inicializar o aplicativo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Erro: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  main();
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class TorcidaHubApp extends StatefulWidget {
  final AuthServiceSupabase authService;
  
  const TorcidaHubApp({
    super.key,
    required this.authService,
  });

  @override
  State<TorcidaHubApp> createState() => _TorcidaHubAppState();
}

class _TorcidaHubAppState extends State<TorcidaHubApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _setupAuthListener();
  }

  Future<void> _checkAuthState() async {
    // Garantir que a splash seja exibida pelo menos 2 segundos
    await Future.delayed(const Duration(seconds: 2));
    final session = SupabaseService.auth.currentSession;
    if (mounted) {
      setState(() {
        _isAuthenticated = session != null;
        _isLoading = false;
      });
    }
  }

  void _setupAuthListener() {
    // Escutar mudanças de autenticação (similar ao AuthContext do React)
    SupabaseService.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final session = data.session;

      // Ignorar TOKEN_REFRESHED para evitar re-renders desnecessários
      if (event == AuthChangeEvent.tokenRefreshed) {
        return;
      }

      final isAuthenticated = session != null;
      
      if (_isAuthenticated != isAuthenticated) {
        setState(() {
          _isAuthenticated = isAuthenticated;
        });

        // Navegar para a tela apropriada
        if (_navigatorKey.currentState != null) {
          if (isAuthenticated) {
            _navigatorKey.currentState!.pushReplacementNamed('/dashboard');
          } else {
            _navigatorKey.currentState!.pushReplacementNamed('/login');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TorcidaHub',
        home: const SplashScreen(),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TorcidaHub',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.hubBlue,
        ),
      ),
      initialRoute: _isAuthenticated ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
      onGenerateRoute: (settings) {
        // Rota dinâmica para /minha-torcida/:id
        if (settings.name != null && settings.name!.startsWith('/minha-torcida/')) {
          final fanClubId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => MinhaTorcidaScreen(fanClubId: fanClubId),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
