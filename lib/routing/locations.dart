/// Loan [loanId], opened from Alerts: it sits on top of the Alerts tab, so
/// back returns there, even when it was opened from a push.
String alertLoanLocation(String loanId) =>
    '/alerts/loans/${Uri.encodeComponent(loanId)}';

/// Loan [loanId], opened from My Loans; back returns there.
String myLoanLocation(String loanId) => '/loans/${Uri.encodeComponent(loanId)}';
