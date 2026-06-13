import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AppDependenciesScope.of(context).authRepository.register(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        address: _addressController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.appShell, (_) => false);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to create account right now.');
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

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
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
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  void _goBack() {
    if (!_isLoading) {
      Navigator.of(context).pop();
    }
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
              final content = _RegisterContent(
                compact: !isWide,
                formKey: _formKey,
                firstNameController: _firstNameController,
                lastNameController: _lastNameController,
                emailController: _emailController,
                addressController: _addressController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                isLoading: _isLoading,
                requiredValidator: _required,
                validateEmail: _validateEmail,
                validatePassword: _validatePassword,
                onSubmit: _submit,
                onTogglePassword: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                onBack: _goBack,
              );
              final card = isWide
                  ? SizedBox(
                      height: math.max(760, constraints.maxHeight - 112),
                      child: _DesktopRegisterCard(
                        content: content,
                        onBack: _goBack,
                      ),
                    )
                  : _MobileRegisterCard(content: content, onBack: _goBack);

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 28 : 14,
                      isWide ? 28 : 14,
                      isWide ? 28 : 14,
                      14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1380),
                          child: card,
                        ),
                        const SizedBox(height: 18),
                        const _RegisterFooter(),
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
}

class _DesktopRegisterCard extends StatelessWidget {
  const _DesktopRegisterCard({required this.content, required this.onBack});

  final Widget content;
  final VoidCallback onBack;

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
            Expanded(flex: 35, child: _RegisterBrandPanel(onBack: onBack)),
            Expanded(
              flex: 65,
              child: ColoredBox(color: Colors.white, child: content),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileRegisterCard extends StatelessWidget {
  const _MobileRegisterCard({required this.content, required this.onBack});

  final Widget content;
  final VoidCallback onBack;

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
            _RegisterMobileBanner(onBack: onBack),
            ColoredBox(color: Colors.white, child: content),
          ],
        ),
      ),
    );
  }
}

class _RegisterBrandPanel extends StatelessWidget {
  const _RegisterBrandPanel({required this.onBack});

  final VoidCallback onBack;

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
              colors: [Color(0xD4072C59), Color(0x18072C59), Color(0xD9052447)],
              stops: [0, 0.52, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 28, 38, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelBackButton(
                key: const Key('register_top_back_button'),
                onPressed: onBack,
              ),
              const SizedBox(height: 70),
              const Text(
                'Create your account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Join SentryMesh and stay protected.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const _RegisterSecurityMessage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegisterMobileBanner extends StatelessWidget {
  const _RegisterMobileBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/sentrymesh_security.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.08),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xE8072C59),
                  Color(0x30072C59),
                  Color(0xA9052447),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelBackButton(
                  key: const Key('register_top_back_button'),
                  onPressed: onBack,
                  compact: true,
                ),
                const Spacer(),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Join SentryMesh and stay protected.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
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

class _PanelBackButton extends StatelessWidget {
  const _PanelBackButton({
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 0, vertical: 8),
        textStyle: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(Icons.arrow_back_rounded, size: compact ? 18 : 20),
      label: const Text('Back to Sign In'),
    );
  }
}

class _RegisterSecurityMessage extends StatelessWidget {
  const _RegisterSecurityMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF174A7D).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF1268D6),
            child: Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 25,
            ),
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
                  'We keep your account details safe and secure.',
                  style: TextStyle(
                    color: Color(0xFFC9DCF0),
                    fontSize: 11,
                    height: 1.35,
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

typedef RequiredValidator = String? Function(String? value, String label);

class _RegisterContent extends StatelessWidget {
  const _RegisterContent({
    required this.compact,
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.addressController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.requiredValidator,
    required this.validateEmail,
    required this.validatePassword,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onBack,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final RequiredValidator requiredValidator;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 48,
        vertical: compact ? 26 : 34,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProfileHeading(),
              SizedBox(height: compact ? 24 : 30),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final sideBySide = constraints.maxWidth >= 580;
                        final firstNameField = TextFormField(
                          key: const Key('register_first_name_field'),
                          controller: firstNameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              requiredValidator(value, 'First name'),
                          decoration: _fieldDecoration(
                            label: 'First name',
                            hint: 'Enter your first name',
                            icon: Icons.badge_outlined,
                          ),
                        );
                        final lastNameField = TextFormField(
                          key: const Key('register_last_name_field'),
                          controller: lastNameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              requiredValidator(value, 'Last name'),
                          decoration: _fieldDecoration(
                            label: 'Last name',
                            hint: 'Enter your last name',
                            icon: Icons.badge_outlined,
                          ),
                        );

                        if (!sideBySide) {
                          return Column(
                            children: [
                              firstNameField,
                              const SizedBox(height: 12),
                              lastNameField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: firstNameField),
                            const SizedBox(width: 16),
                            Expanded(child: lastNameField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('register_email_field'),
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: validateEmail,
                      decoration: _fieldDecoration(
                        label: 'Email address',
                        hint: 'Enter your email address',
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('register_address_field'),
                      controller: addressController,
                      textInputAction: TextInputAction.next,
                      validator: (value) => requiredValidator(value, 'Address'),
                      decoration: _fieldDecoration(
                        label: 'Address',
                        hint: 'Enter your address',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: passwordController,
                      obscurePassword: obscurePassword,
                      validatePassword: validatePassword,
                      onTogglePassword: onTogglePassword,
                      onSubmit: onSubmit,
                    ),
                    SizedBox(height: compact ? 18 : 22),
                    _CreateAccountButton(
                      isLoading: isLoading,
                      onPressed: onSubmit,
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              const _OrDivider(),
              SizedBox(height: compact ? 16 : 20),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('register_back_button'),
                  onPressed: isLoading ? null : onBack,
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
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text('Back to Sign In'),
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
    required String hint,
    required IconData icon,
  }) {
    return _registerFieldDecoration(label: label, hint: hint, icon: icon);
  }
}

class _ProfileHeading extends StatelessWidget {
  const _ProfileHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: AppTheme.signalBlue,
            size: 33,
          ),
        ),
        const SizedBox(width: 17),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resident profile',
                style: TextStyle(
                  color: Color(0xFF0A2D56),
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Create your SentryMesh account.',
                style: TextStyle(
                  color: Color(0xFF667991),
                  fontSize: 14,
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.validatePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool obscurePassword;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          key: const Key('register_password_field'),
          controller: controller,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          validator: validatePassword,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: _registerFieldDecoration(
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 13),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F6FF),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 17,
                    color: AppTheme.signalBlue,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Password must include:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF075BBF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 7),
                    const _PasswordRule(label: '8+ characters'),
                  ],
                );
              }

              return Wrap(
                spacing: 18,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  heading,
                  const _PasswordRule(label: '8+ characters'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 7,
          backgroundColor: Color(0xFFD4E5FF),
          child: Icon(Icons.check, size: 10, color: AppTheme.signalBlue),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF607895),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

InputDecoration _registerFieldDecoration({
  required String label,
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  const borderColor = Color(0xFFC9D8E8);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    labelStyle: const TextStyle(
      color: Color(0xFF425B79),
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF8292A7),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    prefixIconColor: const Color(0xFF66809F),
    suffixIconColor: const Color(0xFF66809F),
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

class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
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
        key: const Key('register_submit_button'),
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
                    Icon(Icons.person_add_alt_1_rounded, size: 21),
                    SizedBox(width: 10),
                    Text(
                      'Create Account',
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD4E0ED))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF71849A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD4E0ED))),
      ],
    );
  }
}

class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: AppTheme.signalBlue,
          size: 22,
        ),
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
          '(c) ${DateTime.now().year} All rights reserved.',
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
