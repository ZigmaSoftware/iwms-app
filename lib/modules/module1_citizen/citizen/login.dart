import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';
import 'package:iwms_citizen_app/core/ui/app_copy.dart';

import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../../logic/auth/auth_state.dart';

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
    context.read<AuthBloc>().add(
          AuthCitizenLoginRequested(
            username: _phoneController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.58),
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        size: 21,
        color: Colors.white.withValues(alpha: 0.85),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFB4A8), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFD1C8), width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFFDED8),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.playfairDisplayTextTheme(theme.textTheme);
    final bodyTheme = GoogleFonts.rubikTextTheme(theme.textTheme);
    final themedContext = theme.copyWith(
      textTheme: bodyTheme.copyWith(
        displayLarge: textTheme.displayLarge,
        headlineMedium: textTheme.headlineMedium,
        headlineSmall: textTheme.headlineSmall,
      ),
    );

    return Theme(
      data: themedContext,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _LoginBackground(),
            SafeArea(
              child: BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthStateFailure) {
                    _showSnack(state.message, Colors.red);
                  }
                },
                builder: (context, state) {
                  final isLoading = state is AuthStateLoading;
                  return Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 56,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  child: _LoginGlassCard(
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
                                        const Color(0xFF1B2F72),
                                      );
                                    },
                                    onLogin: () => _handleLogin(context),
                                    isSubmitting: isLoading,
                                    inputDecorationBuilder: _inputDecoration,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const _ScreenAnchoredLeaf(),
          ],
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.authBackground,
          fit: BoxFit.cover,
        ),
        // Keep the leaf texture visible, but lower the exposure behind glass.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.100),
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.900),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenAnchoredLeaf extends StatelessWidget {
  const _ScreenAnchoredLeaf();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = (size.height * 0.035).clamp(26.0, 48.0);
    final leafWidth = (size.width * 0.72).clamp(250.0, 305.0);

    return Positioned(
      top: top,
      right: -leafWidth * 0.50,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.25,
          alignment: Alignment.centerRight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(20, 1),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 5),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.90),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(
                      AppAssets.loginLeafBranch,
                      width: leafWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Image.asset(
                AppAssets.loginLeafBranch,
                width: leafWidth,
                fit: BoxFit.contain,
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 900.ms)
              .slideX(begin: 0.16, end: 0, duration: 950.ms)
              .then()
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .rotate(
                alignment: Alignment.centerRight,
                begin: -0.014,
                end: 0.014,
                duration: 4300.ms,
                curve: Curves.easeInOutSine,
              ),
        ),
      ),
    );
  }
}

/// Faithful port of the liquid-glass recipe:
/// glass-filter (blur + saturate 120% + brightness 1.15),
/// glass-overlay (white 25%), glass-specular (inset highlight + inner glow),
/// then glass-content on top.
class _LiquidGlass extends StatelessWidget {
  const _LiquidGlass({
    required this.radius,
    required this.child,
  });

  final double radius;
  final Widget child;

  // saturate(120%) ∘ brightness(1.15) folded into one color matrix.
  static const List<double> _saturateBrighten = [
    1.3310, -0.1645, -0.0166, 0, 0, //
    -0.0490, 1.2156, -0.0166, 0, 0, //
    -0.0490, -0.1645, 1.3634, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.compose(
                  outer: const ui.ColorFilter.matrix(_saturateBrighten),
                  inner: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassSpecularPainter(radius: radius),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Replaces CSS `inset 1px 1px 0 highlight, inset 0 0 5px highlight`:
/// a crisp top-left hairline that fades around the corner plus a soft
/// inner glow clipped to the card.
class _GlassSpecularPainter extends CustomPainter {
  const _GlassSpecularPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final inner = outer.deflate(0.8);

    canvas.save();
    canvas.clipRRect(outer);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawRRect(inner, glow);
    canvas.restore();

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.35, 0.7, 1.0],
        colors: [
          Color(0xD9FFFFFF),
          Color(0x40FFFFFF),
          Color(0x14FFFFFF),
          Color(0x4DFFFFFF),
        ],
      ).createShader(rect);
    canvas.drawRRect(inner, hairline);
  }

  @override
  bool shouldRepaint(covariant _GlassSpecularPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

class _LoginGlassCard extends StatelessWidget {
  const _LoginGlassCard({
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
    required String hint,
    required IconData icon,
  }) inputDecorationBuilder;

  static const Color _buttonCream = Color(0xFFF4F2E7);
  static const Color _textAccent = Color(0xFF1B2F72);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _LiquidGlass(
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 30),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LogoMark().animate().fadeIn(duration: 700.ms).scale(
                            begin: const Offset(0.92, 0.92),
                            duration: 900.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.34),
                          ),
                        ),
                        child: const Text(
                          'IWMS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    AppCopy.loginWelcomeTitle,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Access your collection, route and service dashboard.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.text,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: inputDecorationBuilder(
                      hint: 'Username / Phone',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username or phone';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: inputDecorationBuilder(
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed:
                            isSubmitting ? null : onTogglePasswordVisibility,
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 21,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        tooltip:
                            obscurePassword ? 'Show password' : 'Hide password',
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox.adaptive(
                          value: rememberMe,
                          activeColor: _buttonCream,
                          checkColor: _textAccent,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.4,
                          ),
                          onChanged: isSubmitting ? null : onRememberMeChanged,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Remember me',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isSubmitting ? null : onForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot?',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonCream,
                        foregroundColor: _textAccent,
                        disabledBackgroundColor:
                            _buttonCream.withValues(alpha: 0.7),
                        disabledForegroundColor:
                            _textAccent.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: _textAccent,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  AppCopy.login,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 900.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.05, end: 0, duration: 900.ms);
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Image.asset(AppAssets.logo),
    );
  }
}
