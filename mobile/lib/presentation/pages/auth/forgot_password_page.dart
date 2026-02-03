import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

/// Password reset step enum
enum ResetPasswordStep {
  /// Step 1: Enter email to receive verification code
  email,

  /// Step 2: Enter verification code and new password
  resetPassword,

  /// Step 3: Success - password has been reset
  success,
}

/// Forgot password page
///
/// Provides user interface for:
/// - Email input to request password reset (Step 1)
/// - Verification code and new password input (Step 2)
/// - Success confirmation (Step 3)
///
/// Requirements: 26.1, 26.3
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _verificationCodeFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  ResetPasswordStep _currentStep = ResetPasswordStep.email;

  // Countdown timer for resend verification code
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  static const int _resendCooldown = 60; // 60 seconds cooldown

  @override
  void dispose() {
    _emailController.dispose();
    _verificationCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Start countdown timer for resend button
  void _startCountdown() {
    _countdownSeconds = _resendCooldown;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  /// Handle step 1: Request password reset
  Future<void> _handleRequestReset() async {
    // Validate email
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Prevent double submission
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Clear any previous errors
      ref.read(authProvider.notifier).clearError();

      // Request password reset
      await ref.read(authProvider.notifier).forgotPassword(
            _emailController.text.trim(),
          );

      // Request successful - move to reset password step
      if (mounted) {
        setState(() {
          _currentStep = ResetPasswordStep.resetPassword;
        });
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码已发送到您的邮箱'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Focus on verification code input
        _verificationCodeFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAndShowSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Handle step 2: Reset password with verification code
  Future<void> _handleResetPassword() async {
    // Validate form
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Prevent double submission
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Clear any previous errors
      ref.read(authProvider.notifier).clearError();

      // Reset password
      await ref.read(authProvider.notifier).resetPassword(
            email: _emailController.text.trim(),
            code: _verificationCodeController.text.trim(),
            newPassword: _newPasswordController.text,
          );

      // Reset successful - show success step
      if (mounted) {
        setState(() {
          _currentStep = ResetPasswordStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAndShowSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Resend verification code
  Future<void> _handleResendCode() async {
    if (_countdownSeconds > 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authProvider.notifier).forgotPassword(
            _emailController.text.trim(),
          );

      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码已重新发送'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAndShowSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Go back to previous step
  void _handleBack() {
    if (_currentStep == ResetPasswordStep.resetPassword) {
      setState(() {
        _currentStep = ResetPasswordStep.email;
        _verificationCodeController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } else {
      context.pop();
    }
  }

  /// Navigate back to login page
  void _navigateToLogin() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading || _isSubmitting;

    return Scaffold(
      appBar: _currentStep != ResetPasswordStep.success
          ? AppBar(
              title: Text(_getAppBarTitle()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isLoading ? null : _handleBack,
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildCurrentStep(isLoading),
        ),
      ),
    );
  }

  /// Get app bar title based on current step
  String _getAppBarTitle() {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return '忘记密码';
      case ResetPasswordStep.resetPassword:
        return '重置密码';
      case ResetPasswordStep.success:
        return '';
    }
  }

  /// Build current step widget
  Widget _buildCurrentStep(bool isLoading) {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return _buildEmailStep(isLoading);
      case ResetPasswordStep.resetPassword:
        return _buildResetPasswordStep(isLoading);
      case ResetPasswordStep.success:
        return _buildSuccessStep();
    }
  }

  /// Build step 1: Email input
  Widget _buildEmailStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          '找回密码',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '请输入您注册时使用的邮箱地址，我们将发送验证码到该邮箱',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        ),
        const SizedBox(height: 32),

        // Email input
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !isLoading,
          decoration: const InputDecoration(
            labelText: '邮箱',
            hintText: '请输入邮箱地址',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: Validators.validateEmail,
          onFieldSubmitted: (_) => _handleRequestReset(),
        ),
        const SizedBox(height: 32),

        // Send code button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleRequestReset,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '发送验证码',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Back to login link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '想起密码了？',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: isLoading ? null : _navigateToLogin,
              child: const Text('返回登录'),
            ),
          ],
        ),
      ],
    );
  }

  /// Build step 2: Reset password with verification code
  Widget _buildResetPasswordStep(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            '设置新密码',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '验证码已发送至 ${_emailController.text}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          const SizedBox(height: 32),

          // Verification code input
          TextFormField(
            controller: _verificationCodeController,
            focusNode: _verificationCodeFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '验证码',
              hintText: '请输入6位验证码',
              prefixIcon: Icon(Icons.verified_outlined),
              counterText: '',
            ),
            validator: Validators.validateVerificationCode,
            onFieldSubmitted: (_) {
              _newPasswordFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 8),

          // Resend code button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    (_countdownSeconds > 0 || isLoading) ? null : _handleResendCode,
                child: Text(
                  _countdownSeconds > 0
                      ? '重新发送 (${_countdownSeconds}s)'
                      : '重新发送',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // New password input
          TextFormField(
            controller: _newPasswordController,
            focusNode: _newPasswordFocusNode,
            obscureText: _obscureNewPassword,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: '新密码',
              hintText: '至少8位，包含字母和数字',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        setState(
                            () => _obscureNewPassword = !_obscureNewPassword);
                      },
              ),
            ),
            validator: Validators.validatePassword,
            onFieldSubmitted: (_) {
              _confirmPasswordFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 16),

          // Confirm password input
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: '确认新密码',
              hintText: '请再次输入新密码',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
              ),
            ),
            validator: (value) => Validators.validatePasswordConfirmation(
              value,
              _newPasswordController.text,
            ),
            onFieldSubmitted: (_) => _handleResetPassword(),
          ),
          const SizedBox(height: 32),

          // Reset password button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleResetPassword,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '重置密码',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '验证码有效期为10分钟，请尽快完成重置',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build step 3: Success confirmation
  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),

        // Success icon
        Icon(
          Icons.check_circle_outline,
          size: 100,
          color: AppColors.success,
        ),
        const SizedBox(height: 24),

        // Success message
        Text(
          '密码重置成功',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '您的密码已成功重置，请使用新密码登录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Back to login button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _navigateToLogin,
            child: const Text(
              '返回登录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
