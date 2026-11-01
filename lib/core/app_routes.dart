import 'package:flutter/widgets.dart';

import '../screens/forgot_password_screen.dart';
import '../screens/register_screen.dart';

/// Rutas con nombre de las pantallas secundarias sin sesión.
///
/// Login y Home NO son rutas: los muestra `AuthGate` según el estado de la
/// sesión, así no se puede abrir Home sin haber iniciado sesión.
class AppRoutes {
  AppRoutes._();

  static const forgotPassword = '/forgot-password';
  static const register = '/register';

  static final Map<String, WidgetBuilder> table = {
    forgotPassword: (_) => const ForgotPasswordScreen(),
    register: (_) => const RegisterScreen(),
  };
}
