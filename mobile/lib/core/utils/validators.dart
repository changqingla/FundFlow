/// Utility class for input validation
///
/// Provides validation functions for:
/// - Email format validation (Requirement 23.1)
/// - Password strength validation (Requirement 26.4)
/// - Verification code validation (Requirement 23.3)
/// - Fund code validation
/// - Nickname validation
class Validators {
  Validators._();

  /// Validate email format
  ///
  /// Returns null if valid, error message if invalid.
  ///
  /// Requirements: 23.1
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入邮箱地址';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }

    return null;
  }

  /// Validate password strength
  ///
  /// Password must:
  /// - Be at least 8 characters long
  /// - Contain at least one letter
  /// - Contain at least one digit
  ///
  /// Returns null if valid, error message if invalid.
  ///
  /// Requirements: 26.4
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }

    if (value.length < 8) {
      return '密码长度至少为8位';
    }

    // Check for at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return '密码必须包含字母';
    }

    // Check for at least one digit
    if (!RegExp(r'\d').hasMatch(value)) {
      return '密码必须包含数字';
    }

    return null;
  }

  /// Validate password confirmation
  ///
  /// Checks that the confirmation matches the original password.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validatePasswordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }

    if (value != password) {
      return '两次输入的密码不一致';
    }

    return null;
  }

  /// Validate verification code
  ///
  /// Verification code must be exactly 6 digits.
  ///
  /// Returns null if valid, error message if invalid.
  ///
  /// Requirements: 23.3
  static String? validateVerificationCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }

    if (value.length != 6) {
      return '验证码为6位数字';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return '验证码必须为6位数字';
    }

    return null;
  }

  /// Validate fund code
  ///
  /// Fund codes are typically 6 digits.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateFundCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入基金代码';
    }

    // Fund codes are typically 6 digits
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return '请输入有效的6位基金代码';
    }

    return null;
  }

  /// Validate required field
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateRequired(String? value, {String fieldName = '此字段'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName不能为空';
    }
    return null;
  }

  /// Validate nickname
  ///
  /// Nickname is optional but if provided, must be <= 20 characters.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Nickname is optional
    }

    if (value.length > 20) {
      return '昵称长度不能超过20个字符';
    }

    return null;
  }

  /// Check if email format is valid (returns boolean)
  ///
  /// Useful for quick validation without error messages.
  static bool isValidEmail(String? value) {
    return validateEmail(value) == null;
  }

  /// Check if password meets strength requirements (returns boolean)
  ///
  /// Useful for quick validation without error messages.
  static bool isValidPassword(String? value) {
    return validatePassword(value) == null;
  }

  /// Check if verification code is valid (returns boolean)
  ///
  /// Useful for quick validation without error messages.
  static bool isValidVerificationCode(String? value) {
    return validateVerificationCode(value) == null;
  }

  /// Check if fund code is valid (returns boolean)
  ///
  /// Useful for quick validation without error messages.
  static bool isValidFundCode(String? value) {
    return validateFundCode(value) == null;
  }
}
