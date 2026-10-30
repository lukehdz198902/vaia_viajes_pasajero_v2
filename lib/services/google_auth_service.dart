import 'package:google_sign_in/google_sign_in.dart';
import 'logger.dart';

/// Autenticacion con Google usando google_sign_in 7.x.
///
/// Para obtener el idToken (que valida el backend) es necesario configurar
/// el "server client ID": el cliente OAuth 2.0 de tipo **Web** del proyecto
/// de Google Cloud / Firebase. Se puede pasar al compilar:
///
///   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
///
/// Si no se define, el plugin toma el cliente web que venga en
/// `android/app/google-services.json` (requiere registrar la huella SHA-1).
class GoogleAuthService {
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // Cliente OAuth Web del proyecto vaia-9760b. Se usa para solicitar el
    // idToken que valida la API. Se puede sobrescribir con --dart-define.
    defaultValue: '933685582766-f5c2tlo0frhhni5aueb65ev8gtqkc6ra.apps.googleusercontent.com',
  );

  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  /// Devuelve el idToken de Google, o null si el usuario cancela.
  static Future<String?> obtenerIdToken() async {
    await _ensureInit();
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception(
          'Este dispositivo no puede mostrar el selector de cuentas de Google. '
          'Verifica que Google Play Services este instalado y actualizado.',
        );
      }

      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(_mensajeConfiguracion(
          'Google no devolvio el idToken. Esto ocurre cuando la app no tiene '
          'configurado el cliente OAuth web o la huella SHA-1.',
        ));
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        Logger.i('GoogleAuth', 'Inicio de sesion cancelado por el usuario');
        return null;
      }
      Logger.e('GoogleAuth', 'GoogleSignInException: ${e.code} ${e.description}');
      throw Exception(_mensajeConfiguracion(e.description ?? ''));
    }
  }

  /// Traduce los errores mas comunes de Google Sign-In a instrucciones claras.
  static String _mensajeConfiguracion(String detalle) {
    final d = detalle.toLowerCase();
    final esConfiguracion = d.contains('clientid') ||
        d.contains('client id') ||
        d.contains('10:') ||
        d.contains('developer_error') ||
        d.contains('audience') ||
        d.contains('sha-1') ||
        d.contains('sha1') ||
        d.contains('oauth') ||
        d.contains('idtoken');

    if (esConfiguracion) {
      return 'Google Sign-In no esta configurado para esta app. '
          'Registra la huella SHA-1 en Firebase (proyecto vaia-9760b), '
          'descarga de nuevo google-services.json y compila con el client ID web.';
    }
    return detalle.isNotEmpty ? detalle : 'No se pudo iniciar sesion con Google.';
  }
}
