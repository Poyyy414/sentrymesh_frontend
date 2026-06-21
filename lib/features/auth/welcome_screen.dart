import 'package:flutter/material.dart';

import '../../app/assets.dart';
import '../../app/router.dart';
import '../../app/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              const _LogoSection(),
              const SizedBox(height: 10),
              const _TaglineText(),
              const SizedBox(height: 4),
              const _IllustrationSection(),
              const SizedBox(height: 0),
              const Divider(
                color: Color(0xFF0B4778),
                thickness: 1.2,
              ),
              const SizedBox(height: 70),
              _RegisterButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.register),
              ),
              const SizedBox(height: 20),
              _LoginButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.login),
              ),
              const SizedBox(height: 20),
              const _WelcomeFooter(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(AppAssets.appIcon, width: 52, height: 52),
        ),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Sentry',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Mesh',
                style: TextStyle(
                  color: Color(0xFF0B4778),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaglineText extends StatelessWidget {
  const _TaglineText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '"No Internet. No Power.\nStill Connected"',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.45,
      ),
    );
  }
}

class _IllustrationSection extends StatelessWidget {
  const _IllustrationSection();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/sentrymesh_worker.png',
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, _, _) => const SizedBox(
        height: 200,
        child: _FallbackIllustration(),
      ),
    );
  }
}

class _FallbackIllustration extends StatelessWidget {
  const _FallbackIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F6FF),
            shape: BoxShape.circle,
          ),
        ),
        const Icon(
          Icons.person_pin_circle_rounded,
          size: 86,
          color: AppTheme.navy,
        ),
        Positioned(
          top: 18,
          left: 32,
          child: _IconBubble(
            icon: Icons.satellite_alt_rounded,
            color: AppTheme.signalBlue,
          ),
        ),
        Positioned(
          top: 18,
          right: 32,
          child: _IconBubble(
            icon: Icons.location_on_rounded,
            color: AppTheme.warningAmber,
          ),
        ),
        Positioned(
          bottom: 28,
          left: 24,
          child: _IconBubble(
            icon: Icons.shield_rounded,
            color: AppTheme.safeGreen,
          ),
        ),
        Positioned(
          bottom: 28,
          right: 24,
          child: _IconBubble(
            icon: Icons.chat_bubble_rounded,
            color: AppTheme.violet,
          ),
        ),
        Positioned(
          top: 52,
          left: 10,
          child: _IconBubble(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.dangerRed,
            small: true,
          ),
        ),
        Positioned(
          top: 52,
          right: 10,
          child: _IconBubble(
            icon: Icons.medical_services_rounded,
            color: AppTheme.safeGreen,
            small: true,
          ),
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.color,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    final iconSize = small ? 17.0 : 21.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x280B4778),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Register',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.navy,
          side: const BorderSide(color: Color(0xFFBDCEE2), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: const Text('Log In'),
      ),
    );
  }
}

class _WelcomeFooter extends StatelessWidget {
  const _WelcomeFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_rounded, color: Color(0xFF9BADC0), size: 14),
        const SizedBox(width: 6),
        Text(
          '© ${DateTime.now().year} SentryMesh. All rights reserved.',
          style: const TextStyle(
            color: Color(0xFF9BADC0),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
