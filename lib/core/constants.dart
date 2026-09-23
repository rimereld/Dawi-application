/// App-wide constants shared across screens.
class AppLanguages {
  AppLanguages._();
  static const List<String> all = ['Français', 'العربية', 'Darija', 'Tamazight', 'English'];
}

/// Document type machine values (used by the API) mapped to display labels.
class DocumentTypes {
  DocumentTypes._();

  static const String prescription = 'prescription';
  static const String labReport = 'lab_report';
  static const String medicalReport = 'medical_report';
  static const String certificate = 'certificate';
  static const String imaging = 'imaging';
  static const String other = 'other';

  static const List<String> all = [
    prescription,
    labReport,
    medicalReport,
    certificate,
    imaging,
    other,
  ];

  static String label(String value) {
    switch (value) {
      case prescription:
        return 'Prescription';
      case labReport:
        return 'Lab Report';
      case medicalReport:
        return 'Medical Report';
      case certificate:
        return 'Certificate';
      case imaging:
        return 'Imaging';
      default:
        return 'Other';
    }
  }
}

/// Medication status machine values mapped to display labels.
class MedicationStatus {
  MedicationStatus._();
  static const String active = 'active';
  static const String completed = 'completed';
  static const String upcoming = 'upcoming';
  static const List<String> all = [active, completed, upcoming];

  static String label(String value) =>
      value.isEmpty ? '' : '${value[0].toUpperCase()}${value.substring(1)}';
}

/// Appointment status machine values mapped to display labels.
class AppointmentStatus {
  AppointmentStatus._();
  static const String upcoming = 'upcoming';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}
