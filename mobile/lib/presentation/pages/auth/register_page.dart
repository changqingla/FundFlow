import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

/// Registration step enum
enum RegisterStep {
  /// Step 1: Enter email and password
  emailPassword,

  /// Step 2: Enter verification code
  verification,
}

/// Register page
///
/// Provides user interface for:
/// - Email and password input (Step 1)
/// - Verification code input (Step 2)
/// - Password confirmation
/// - Countdown timer for resending verification code
///
/// Requirements: 23.1, 23.4
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _nicknameFocusNode = FocusNode();
  final _verificationCodeFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  RegisterStep _currentStep = RegisterStep.emailPassword;

  // Countdown timer for resend verification code
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  static const int _resendCooldown = 60; // 60 seconds cooldown

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _verificationCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
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

  /// Handle step 1: Register and send verification code
  Future<void> _handleRegister() async {
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

      // Attempt registration
      await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
          );

      // Registration successful - move to verification step
      if (mounted) {
        setState(() {
          _currentStep = RegisterStep.verification;
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

  /// Handle step 2: Verify email with code
  Future<void> _handleVerifyEmail() async {
    // Validate verification code
    final codeError =
        Validators.validateVerificationCode(_verificationCodeController.text);
    if (codeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(codeError),
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

      // Attempt email verification
      await ref.read(authProvider.notifier).verifyEmail(
            email: _emailController.text.trim(),
            code: _verificationCodeController.text.trim(),
          );

      // Verification successful
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('注册成功！请登录'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to login page
        context.pop();
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
      // Re-register to resend verification code
      await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
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
    if (_currentStep == RegisterStep.verification) {
      setState(() {
        _currentStep = RegisterStep.emailPassword;
        _verificationCodeController.clear();
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading || _isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == RegisterStep.emailPassword ? '注册' : '验证邮箱'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isLoading ? null : _handleBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _currentStep == RegisterStep.emailPassword
              ? _buildEmailPasswordStep(isLoading)
              : _buildVerificationStep(isLoading),
        ),
      ),
    );
  }

  /// Build step 1: Email and password input
  Widget _buildEmailPasswordStep(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            '创建账号',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '请填写以下信息完成注册',
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
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: const InputDecoration(
              labelText: '邮箱 *',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: Validators.validateEmail,
            onFieldSubmitted: (_) {
              _passwordFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 16),

          // Password input
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: '密码 *',
              hintText: '至少8位，包含字母和数字',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() => _obscurePassword = !_obscurePassword);
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
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: '确认密码 *',
              hintText: '请再次输入密码',
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
              _passwordController.text,
            ),
            onFieldSubmitted: (_) {
              _nicknameFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 16),

          // Nickname input (optional)
          TextFormField(
            controller: _nicknameController,
            focusNode: _nicknameFocusNode,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            decoration: const InputDecoration(
              labelText: '昵称（可选）',
              hintText: '请输入昵称',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: Validators.validateNickname,
            onFieldSubmitted: (_) => _handleRegister(),
          ),
          const SizedBox(height: 32),

          // Register button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleRegister,
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
                      '获取验证码',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Login link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '已有账号？',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: isLoading ? null : () => context.pop(),
                child: const Text('立即登录'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build step 2: Verification code input
  Widget _buildVerificationStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          '验证邮箱',
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
          textInputAction: TextInputAction.done,
          enabled: !isLoading,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '验证码',
            hintText: '请输入6位验证码',
            prefixIcon: Icon(Icons.verified_outlined),
            counterText: '',
          ),
          validator: Validators.validateVerificationCode,
          onFieldSubmitted: (_) => _handleVerifyEmail(),
        ),
        const SizedBox(height: 16),

        // Resend code button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '没有收到验证码？',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed:
                  (_countdownSeconds > 0 || isLoading) ? null : _handleResendCode,
              child: Text(
                _countdownSeconds > 0 ? '重新发送 (${_countdownSeconds}s)' : '重新发送',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Verify button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleVerifyEmail,
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
                    '完成注册',
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
                  '验证码有效期为10分钟，请尽快完成验证',
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
    );
  }
}
