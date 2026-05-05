import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';
import 'package:iwms_citizen_app/core/ui/app_copy.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';
import 'package:iwms_citizen_app/shared/widgets/app_primary_button.dart';
import 'package:iwms_citizen_app/shared/widgets/brand_logo_badge.dart';

import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../../logic/auth/auth_state.dart';
import 'auth_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _handleLogin(BuildContext context) {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showSnack('Please enter a valid username and password.', Colors.red);
      return;
    }
    FocusScope.of(context).unfocus();
    final username = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    context.read<AuthBloc>().add(
          AuthCitizenLoginRequested(
            username: username,
            password: password,
          ),
        );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF1B5E20)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
        borderSide: const BorderSide(color: Color(0xFFBBDCC1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
        borderSide: const BorderSide(color: Color(0xFFBBDCC1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.rubikTextTheme(theme.textTheme);
    final primaryTextTheme = GoogleFonts.rubikTextTheme(theme.primaryTextTheme);
    final themedContext = theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );

    return Theme(
      data: themedContext,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuthBackground(),
            SafeArea(
              child: BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthStateFailure) {
                    _showSnack(state.message, Colors.red);
                  }
                },
                builder: (context, state) {
                  final bool isLoading = state is AuthStateLoading;
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: const BrandLogoBadge(
                                size: 82,
                                padding: 16,
                                backgroundOpacity: 1,
                                shadow: AppUiTokens.elevatedCardShadow,
                              ),
                            ),
                            const SizedBox(height: AppUiTokens.spacing24),
                            _LoginCard(
                              formKey: _formKey,
                              phoneController: _phoneController,
                              passwordController: _passwordController,
                              rememberMe: _rememberMe,
                              obscurePassword: _obscurePassword,
                              onRememberMeChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              onTogglePasswordVisibility: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onForgotPassword: () {
                                _showSnack(
                                  'Password resets will arrive shortly!',
                                  const Color(0xFF1B5E20),
                                );
                              },
                              onLogin: () => _handleLogin(context),
                              isSubmitting: isLoading,
                              inputDecorationBuilder: _inputDecoration,
                            ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black26,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.rememberMe,
    required this.obscurePassword,
    required this.onRememberMeChanged,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onLogin,
    required this.isSubmitting,
    required this.inputDecorationBuilder,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool obscurePassword;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
  final VoidCallback onLogin;
  final bool isSubmitting;
  final InputDecoration Function({
    required String label,
    required String hint,
    required IconData icon,
  }) inputDecorationBuilder;

  static const Color _primaryGreen = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppUiTokens.spacing32),
        boxShadow: const [AppUiTokens.elevatedCardShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUiTokens.spacing32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    AppAssets.authBackground,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(210, 27, 94, 32),
                          Color.fromARGB(210, 46, 125, 90),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          AppCopy.loginWelcomeTitle,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppCopy.loginWelcomeSubtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.text,
                      decoration: inputDecorationBuilder(
                        label: 'Username / Phone',
                        hint: 'Enter your username or registered phone',
                        icon: Icons.phone_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your username or phone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: inputDecorationBuilder(
                        label: 'Password',
                        hint: 'Enter a secure password',
                        icon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          onPressed:
                              isSubmitting ? null : onTogglePasswordVisibility,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF1B5E20),
                          ),
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your password';
                        }
                        if (value.trim().length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox.adaptive(
                              value: rememberMe,
                              activeColor: _primaryGreen,
                              onChanged:
                                  isSubmitting ? null : onRememberMeChanged,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Remember me',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: TextButton(
                            onPressed: isSubmitting ? null : onForgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerRight,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppPrimaryButton(
                      label: AppCopy.login,
                      onPressed: isSubmitting ? null : onLogin,
                      backgroundColor: _primaryGreen,
                      borderRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
