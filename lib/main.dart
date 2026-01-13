import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/home_screen.dart';
import 'screens/client/client_home_screen.dart';
import 'services/auth_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('pt_BR', null);
    
    AuthService? authService;
    
    try {
      authService = AuthService();
      
      await authService.initialize();
    } catch (e) {
      authService = AuthService();
    }

    runApp(AgendaDeFestaApp(authService: authService));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao inicializar o aplicativo',
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

class AgendaDeFestaApp extends StatefulWidget {
  final AuthService authService;
  
  const AgendaDeFestaApp({
    super.key,
    required this.authService,
  });

  @override
  State<AgendaDeFestaApp> createState() => _AgendaDeFestaAppState();
}

class _AgendaDeFestaAppState extends State<AgendaDeFestaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Configurar callback para logout automático
    widget.authService.setOnTokenInvalidCallback(() {
      _navigateToLogin();
    });
  }

  void _navigateToLogin() {
    if (_navigatorKey.currentState != null) {
      _navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  String _getInitialRoute() {
    final userType = widget.authService.userType;
    if (userType == 2) {
      return '/client-home';
    } else if (userType == 8) {
      return '/home';
    }
    // Padrão: admin home
    return '/home';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doméstica +',
      navigatorKey: _navigatorKey,
      localizationsDelegates: [
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
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: widget.authService.isAuthenticated ? _getInitialRoute() : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/client-home': (context) => const ClientHomeScreen(),
      },
    );
  }
}
