/// A successful `POST /auth/login-mobile` body, shaped like the backend's
/// `ApiResponse<MobileLoginResponseDto>`.
Map<String, Object?> loginResponse({
  String email = 'a@b.com',
  String username = 'juan',
  String accessToken = 'access-token',
  String refreshToken = 'refresh-token',
}) => {
  'success': true,
  'message': 'Mobile login successful.',
  'data': {
    'user': {
      'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      'username': username,
      'email': email,
      'userRole': 'Student',
    },
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  },
  'errors': null,
};

/// An error body as written by the backend's GlobalExceptionHandler
/// (note: PascalCase, unlike success bodies).
Map<String, Object?> errorResponse(String message) => {
  'Success': false,
  'Message': message,
  'Data': null,
  'Errors': null,
};
