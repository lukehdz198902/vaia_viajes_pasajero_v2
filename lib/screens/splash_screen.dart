import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger.dart';
import '../../services/storage_service.dart';
import '../../services/biometric_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'pin_screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bubbleCtrl;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    // Primer arranque: primero los permisos y la aceptacion de terminos.
    final storage = StorageService();
    final onboarding = await storage.getOnboardingCompletado();
    if (!mounted || _navigated) return;
    if (!onboarding) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }
    // Seguridad por PIN: si esta habilitado, se exige al abrir la app.
    if (await storage.getPinHabilitado()) {
      if (!mounted || _navigated) return;
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PinLockScreen()),
      );
      return;
    }
    // Seguridad biometrica: si esta habilitada, se exige al abrir la app.
    if (await storage.getBiometriaHabilitada()) {
      if (!mounted || _navigated) return;
      final ok = await BiometricService.autenticar(motivo: 'Desbloquea Vaia para continuar');
      if (!mounted || _navigated) return;
      if (!ok) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
    }

    bool isLoggedIn = false;
    try {
      isLoggedIn = await auth.tryAutoLogin();
    } catch (e) {
      Logger.e('Splash', 'tryAutoLogin error: $e');
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _navigated) return;
    _navigated = true;
    Logger.i('Splash', 'navigating to ${isLoggedIn ? 'Home' : 'Login'}');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          _BubblesBackground(controller: _bubbleCtrl),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', width: 180, height: 180),
                  const SizedBox(height: 20),
                  const Text(
                    'Vaia Viajes',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu viaje, tu destino',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 44),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: VaiaColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubblesBackground extends StatelessWidget {
  final AnimationController controller;
  const _BubblesBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bubbles = [
      _BubbleData(left: 0.05, top: 0.10, size: 110, durationMs: 9500, delayMs: 0,    color: VaiaColors.primaryLight),
      _BubbleData(left: 0.80, top: 0.18, size: 180, durationMs: 11000, delayMs: 200,  color: VaiaColors.primary),
      _BubbleData(left: 0.15, top: 0.65, size: 220, durationMs: 13000, delayMs: 400,  color: VaiaColors.primaryLight),
      _BubbleData(left: 0.70, top: 0.78, size: 140, durationMs: 10000, delayMs: 600,  color: VaiaColors.primary),
      _BubbleData(left: 0.45, top: 0.45, size: 80,  durationMs: 9000,  delayMs: 800,  color: VaiaColors.primaryLight),
    ];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: bubbles.map((b) {
            final t = ((controller.value * (10000 / b.durationMs)) + (b.delayMs / b.durationMs)) % 1.0;
            return _Bubble(data: b, t: t);
          }).toList(),
        );
      },
    );
  }
}

class _BubbleData {
  final double left, top, size;
  final int durationMs, delayMs;
  final Color color;
  const _BubbleData({
    required this.left,
    required this.top,
    required this.size,
    required this.durationMs,
    required this.delayMs,
    required this.color,
  });
}

class _Bubble extends StatelessWidget {
  final _BubbleData data;
  final double t;
  const _Bubble({required this.data, required this.t});

  @override
  Widget build(BuildContext context) {
    final dx = (t * 2 - 1) * 30;
    final dy = -t * 60;
    return Positioned(
      left: MediaQuery.of(context).size.width * data.left + dx,
      top: MediaQuery.of(context).size.height * data.top + dy,
      child: IgnorePointer(
        child: Container(
          width: data.size,
          height: data.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                data.color.withOpacity(0.55),
                data.color.withOpacity(0.10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}