import 'package:flutter/material.dart';
import '../../services/auth_service_supabase.dart';
import '../../constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthServiceSupabase();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await _authService.getSavedCredentials();
    if (credentials['email'] != null) {
      setState(() {
        _emailController.text = credentials['email'] ?? '';
        _rememberMe = credentials['rememberMe'] == 'true';
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await _authService.signIn(email, password);

      if (response.user != null) {
        if (_rememberMe) {
          await _authService.saveCredentials(email, password, true);
        } else {
          await _authService.clearSavedCredentials();
        }

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } else {
        throw Exception('Falha ao fazer login. Tente novamente.');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao fazer login';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('invalid login credentials') ||
            errorString.contains('invalid_credentials') ||
            errorString.contains('wrong password') ||
            errorString.contains('user not found')) {
          errorMessage = 'Email ou senha incorretos';
        } else if (errorString.contains('email não verificado') ||
            errorString.contains('email not verified')) {
          errorMessage = 'Email não verificado. Verifique sua caixa de entrada.';
        } else if (errorString.contains('network') ||
            errorString.contains('connection') ||
            errorString.contains('timeout') ||
            errorString.contains('failed host lookup')) {
          errorMessage = 'Erro de conexão. Verifique sua internet.';
        } else if (errorString.contains('too many requests') ||
            errorString.contains('rate limit')) {
          errorMessage = 'Muitas tentativas. Aguarde alguns minutos.';
        } else {
          final match =
              RegExp(r'Exception:\s*(.+?)(?:\n|$)').firstMatch(e.toString());
          if (match != null) {
            errorMessage = match.group(1) ?? 'Erro ao fazer login';
          } else {
            errorMessage = e
                .toString()
                .replaceAll('Exception: ', '')
                .split('\n')
                .first;
            if (errorMessage.isEmpty || errorMessage == 'null') {
              errorMessage = 'Erro ao fazer login. Tente novamente.';
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo: gradiente base + imagem hero discreta + overlay para legibilidade
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gradiente base (verde)
                Positioned.fill(
                  child: DecoratedBox(
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
                ),
                // Hero image - torcida no estádio (discreta). Substitua assets/hero_login.png pela nova imagem.
                Positioned.fill(
                  child: Image.asset(
                    'assets/hero_login.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.24),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                // Overlay escuro para legibilidade
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
              ],
            ),
          ),
          // Conteúdo
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo sem caixa – apenas a logo (fundo transparente)
                      Image.asset(
                        'assets/logo.png',
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.sports_soccer,
                            size: 64,
                            color: AppColors.textLight,
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      // Título
                      Text(
                        'Bem-vindo de volta',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Entre na sua conta para acessar sua torcida',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textLightSecondary.withOpacity(0.95),
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      // Card do formulário – verde escuro semitransparente, integrado ao layout
                      Container(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.textLight.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textLight,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                  color: AppColors.textLightSecondary.withOpacity(0.9),
                                ),
                                hintText: 'seu@email.com',
                                hintStyle: TextStyle(
                                  color: AppColors.textLight.withOpacity(0.5),
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: AppColors.textLight.withOpacity(0.85),
                                  size: 22,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.textLight.withOpacity(0.25),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGreen,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.textLight.withOpacity(0.12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, insira seu email';
                                }
                                if (!value.contains('@')) {
                                  return 'Email inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textLight,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                labelStyle: TextStyle(
                                  color: AppColors.textLightSecondary.withOpacity(0.9),
                                ),
                                hintText: '••••••••',
                                hintStyle: TextStyle(
                                  color: AppColors.textLight.withOpacity(0.5),
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outlined,
                                  color: AppColors.textLight.withOpacity(0.85),
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 22,
                                    color: AppColors.textLight.withOpacity(0.7),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.textLight.withOpacity(0.25),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGreen,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.textLight.withOpacity(0.12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, insira sua senha';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: AppColors.textLight,
                                    checkColor: AppColors.darkGreen,
                                    fillColor: MaterialStateProperty.resolveWith((states) {
                                      if (states.contains(MaterialState.selected)) {
                                        return AppColors.textLight;
                                      }
                                      return Colors.transparent;
                                    }),
                                    side: BorderSide(
                                      color: AppColors.textLight.withOpacity(0.8),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Lembrar-me',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textLight.withOpacity(0.95),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.textLight,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Não tem uma conta? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLightSecondary.withOpacity(0.95),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/register');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Cadastre sua torcida',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
