import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VaiaViajesApp());
}

class VaiaViajesApp extends StatelessWidget {
  const VaiaViajesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final api = ApiService(storage);

    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(api, storage)),
        ChangeNotifierProxyProvider<AuthProvider, RideProvider>(
          create: (ctx) => RideProvider(api, ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (ctx) => ProfileProvider(api, ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (ctx) => ChatProvider(api, ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProv, _) {
          return MaterialApp(
            title: 'Vaia Viajes',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
