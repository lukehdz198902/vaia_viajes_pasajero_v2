import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/vaia_widgets.dart';
import '../../services/logger.dart';
import '../../services/storage_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

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
      backgroundColor: VaiaColors.surface,
      body: Stack(
        children: [
          _BubblesBackground(controller: _bubbleCtrl),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: VaiaColors.primaryGhost,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: VaiaColors.primary.withOpacity(0.20), width: 1.5),
                      boxShadow: VaiaShadows.glow,
                    ),
                    child: const VaiaLogo(size: 80),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Vaia Viajes',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: VaiaColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu viaje, tu destino',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: VaiaColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: VaiaColors.primary,
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