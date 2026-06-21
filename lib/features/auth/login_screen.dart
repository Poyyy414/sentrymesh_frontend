import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AppDependenciesScope.of(context).authRepository.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      final route = switch (user.role) {
        'admin' || 'super_admin' => AppRouter.adminShell,
        'responder' => AppRouter.responderShell,
        _ => AppRouter.appShell,
      };
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to sign in right now.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FAFE), Color(0xFFEDF4FC), Color(0xFFF9FBFE)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final horizontalPadding = isWide ? 32.0 : 14.0;
              final card = isWide
                  ? SizedBox(
                      height: math.max(720, constraints.maxHeight - 112),
                      child: _DesktopAuthCard(
                        form: _buildSignInContent(compact: false),
                      ),
                    )
                  : _MobileAuthCard(form: _buildSignInContent(compact: true));

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isWide ? 28 : 14,
                      horizontalPadding,
                      14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: card,
                        ),
                        const SizedBox(height: 18),
                        const _AuthFooter(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSignInContent({required bool compact}) {
    return _SignInContent(
      compact: compact,
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscurePassword,
      isLoading: _isLoading,
      validateEmail: _validateEmail,
      validatePassword: _validatePassword,
      onSubmit: _submit,
      onTogglePassword: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      onCreateAccount: () =>
          Navigator.of(context).pushNamed(AppRouter.welcome),
    );
  }
}

class _DesktopAuthCard extends StatelessWidget {
  const _DesktopAuthCard({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A15365B),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 37, child: _DesktopBrandPanel()),
            Expanded(
              flex: 63,
              child: ColoredBox(color: Colors.white, child: form),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileAuthCard extends StatelessWidget {
  const _MobileAuthCard({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1615365B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            const _MobileBrandBanner(),
            ColoredBox(color: Colors.white, child: form),
          ],
        ),
      ),
    );
  }
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/sentrymesh_security.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB3072C59), Color(0x00072C59), Color(0xC9052447)],
              stops: [0, 0.48, 1],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(36, 34, 36, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_BrandLockup(), Spacer(), _SecurityMessage()],
          ),
        ),
      ],
    );
  }
}

class _MobileBrandBanner extends StatelessWidget {
  const _MobileBrandBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 205,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/sentrymesh_security.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.1),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xE8072C59),
                  Color(0x32072C59),
                  Color(0xA9052447),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandLockup(compact: true),
                Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Color(0xFF8FD5FF),
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Your security is our priority.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 44.0 : 58.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: compact ? 27 : 35,
          ),
        ),
        SizedBox(width: compact ? 11 : 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SentryMesh',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 23 : 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: compact ? 4 : 7),
              Text(
                'Stay connected. Stay safe.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: compact ? 11 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityMessage extends StatelessWidget {
  const _SecurityMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF174A7D).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: Color(0xFF1E5C96),
            child: Icon(Icons.lock_outline, color: Color(0xFFB9E2FF), size: 22),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your security is our priority.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'SentryMesh protects what matters most.',
                  style: TextStyle(
                    color: Color(0xFFC9DCF0),
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInContent extends StatelessWidget {
  const _SignInContent({
    required this.compact,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.validateEmail,
    required this.validatePassword,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onCreateAccount,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 20.0 : 48.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: compact ? 26 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0A2D56),
                  fontSize: compact ? 26 : 30,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Sign in to continue to your account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667991),
                  fontSize: compact ? 13 : 15,
                ),
              ),
              SizedBox(height: compact ? 22 : 25),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('login_email_field'),
                      controller: emailController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      cursorColor: AppTheme.signalBlue,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: validateEmail,
                      decoration: _fieldDecoration(
                        label: 'Email address',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login_password_field'),
                      controller: passwordController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      cursorColor: AppTheme.signalBlue,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      validator: validatePassword,
                      onFieldSubmitted: (_) => onSubmit(),
                      decoration: _fieldDecoration(
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 20),
                    _SignInButton(isLoading: isLoading, onPressed: onSubmit),
                  ],
                ),
              ),
              SizedBox(height: compact ? 20 : 23),
              const _LabeledDivider(label: 'or'),
              SizedBox(height: compact ? 18 : 20),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('create_account_button'),
                  onPressed: isLoading ? null : onCreateAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF075BBF),
                    side: const BorderSide(
                      color: Color(0xFFB8CDE5),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    const borderColor = Color(0xFFC9D8E8);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(
        color: Color(0xFF687B92),
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: const Color(0xFF71849A),
      suffixIconColor: const Color(0xFF71849A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppTheme.signalBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppTheme.dangerRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppTheme.dangerRed, width: 1.5),
      ),
    );
  }
}

class _LabeledDivider extends StatelessWidget {
  const _LabeledDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD4E0ED))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8CA1),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFD4E0ED))),
      ],
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? const [Color(0xFF8CA9C9), Color(0xFF7799BF)]
              : const [Color(0xFF075CCB), Color(0xFF176ACD)],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24105FB7),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        key: const Key('sign_in_button'),
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  key: ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        const Icon(Icons.shield_rounded, color: Color(0xFF8AA0B8), size: 22),
        const Text(
          'SentryMesh',
          style: TextStyle(
            color: Color(0xFF405775),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text('|', style: TextStyle(color: Color(0xFF9BADC0))),
        Text(
          '© ${DateTime.now().year} All rights reserved.',
          style: const TextStyle(
            color: Color(0xFF74879D),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
