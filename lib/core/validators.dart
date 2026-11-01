/// Validaciones de formularios compartidas por las pantallas de autenticación.
library;

/// Dominio institucional de la Universidad de la Amazonia.
const institutionalDomain = 'udla.edu.co';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _institutionalPattern = RegExp(r'^[^@\s]+@udla\.edu\.co$');

/// Formato general de correo (usuario@dominio.ext).
bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Correo del dominio institucional (@udla.edu.co), sin distinguir mayúsculas.
bool isInstitutionalEmail(String email) =>
    _institutionalPattern.hasMatch(email.trim().toLowerCase());

final _codePattern = RegExp(r'^\d{5,15}$');

/// Código institucional (estudiantil o docente): solo dígitos, de 5 a 15.
bool isValidCode(String code) => _codePattern.hasMatch(code.trim());

/// Cómo interpretar lo que el usuario escribe en el login.
enum LoginIdentifierType { email, code, invalid }

/// Si contiene "@" se trata como correo (debe ser @udla.edu.co);
/// si no, como código institucional.
LoginIdentifierType classifyLoginIdentifier(String input) {
  final value = input.trim();
  if (value.contains('@')) {
    return isInstitutionalEmail(value)
        ? LoginIdentifierType.email
        : LoginIdentifierType.invalid;
  }
  return isValidCode(value)
      ? LoginIdentifierType.code
      : LoginIdentifierType.invalid;
}
