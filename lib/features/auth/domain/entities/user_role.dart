enum UserRole {
  admin('ADMIN'),
  techStaff('TECH_STAFF'),
  custodian('CUSTODIAN'),
  instructor('INSTRUCTOR'),
  unknown('');

  const UserRole(this.claim);

  final String claim;

  static UserRole fromClaim(Object? value) {
    final text = value is List && value.isNotEmpty ? value.first : value;
    if (text is! String) return unknown;
    final normalized = text.trim().toUpperCase();
    return values.firstWhere(
      (r) => r != unknown && r.claim == normalized,
      orElse: () => unknown,
    );
  }

  bool get canAudit => this == admin || this == techStaff || this == custodian;

  bool get canSignOff => this == admin || this == techStaff;
}
