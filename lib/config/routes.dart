import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/service_request_screen.dart';
import '../screens/service_status_screen.dart';
import '../screens/rating_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/history_screen.dart';
import '../screens/trip_detail_screen.dart';
import '../screens/promotions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/report_incident_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String serviceRequest = '/service-request';
  static const String serviceStatus = '/service-status';
  static const String rating = '/rating';
  static const String profile = '/profile';
  static const String favorites = '/favorites';
  static const String history = '/history';
  static const String tripDetail = '/trip-detail';
  static const String promotions = '/promotions';
  static const String settings = '/settings';
  static const String chat = '/chat';
  static const String reportIncident = '/report-incident';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (_) => const SplashScreen(),
      login: (_) => const LoginScreen(),
      register: (_) => const RegisterScreen(),
      home: (_) => const HomeScreen(),
      serviceRequest: (_) => const ServiceRequestScreen(currentLat: 0, currentLng: 0),
      profile: (_) => const ProfileScreen(),
      favorites: (_) => const FavoritesScreen(),
      history: (_) => const HistoryScreen(),
      promotions: (_) => const PromotionsScreen(),
      settings: (_) => const SettingsScreen(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments is Map ? settings.arguments as Map<String, dynamic> : <String, dynamic>{};
    switch (settings.name) {
      case serviceStatus:
        return MaterialPageRoute(builder: (_) => const ServiceStatusScreen());
      case rating:
        return MaterialPageRoute(builder: (_) => const RatingScreen());
      case tripDetail:
        return MaterialPageRoute(
          builder: (_) => TripDetailScreen(idServicio: args['idServicio'] ?? 0),
        );
      case chat:
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            idServicio: args['idServicio'] ?? 0,
            conductorNombre: args['conductorNombre'] ?? 'Conductor',
          ),
        );
      case reportIncident:
        return MaterialPageRoute(
          builder: (_) => ReportIncidentScreen(idServicio: args['idServicio']),
        );
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
