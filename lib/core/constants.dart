class AppConstants {
  // Dominio obligatorio para alumnos/docentes UAEH
  static const String allowedEmailDomain = '@uaeh.edu.mx';

  static bool isValidInstitutionalEmail(String email) {
    return email.trim().toLowerCase().endsWith(allowedEmailDomain);
  }
}