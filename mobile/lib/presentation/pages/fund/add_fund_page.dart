import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/fund_provider.dart';

/// Add fund page with code input and search validation
class AddFundPage extends ConsumerStatefulWidget {
  const AddFundPage({super.key});

  @override
  ConsumerState<AddFundPage> createState() => _AddFundPageState();
}

class _AddFundPageState extends ConsumerState<AddFundPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fundState = ref.watch(fundListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加基金'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '请输入6位基金代码，系统将自动验证并添加到您的自选列表',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Fund code input
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: '基金代码',
                  hintText: '请输入6位基金代码',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _codeController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _codeController.clear();
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入基金代码';
                  }
                  if (value.length != 6) {
                    return '基金代码必须是6位数字';
                  }
                  // Check if already in watchlist
                  final existingFund = ref.read(fundListProvider.notifier).getFundByCode(value);
                  if (existingFund != null) {
                    return '该基金已在自选列表中';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting || fundState.isAddingFund
                      ? null
                      : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting || fundState.isAddingFund
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '添加基金',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              // Popular funds section
              Text(
                '热门基金',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularFunds.map((fund) {
                  return ActionChip(
                    label: Text('${fund['name']} (${fund['code']})'),
                    onPressed: () {
                      _codeController.text = fund['code']!;
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(fundListProvider.notifier)
          .addFund(_codeController.text);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('基金添加成功'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final error = ref.read(fundListProvider).error;
        setState(() {
          _errorMessage = error ?? '添加失败，请检查基金代码是否正确';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Popular funds for quick selection
  static const List<Map<String, String>> _popularFunds = [
    {'code': '000001', 'name': '华夏成长'},
    {'code': '110011', 'name': '易方达中小盘'},
    {'code': '161725', 'name': '招商中证白酒'},
    {'code': '003096', 'name': '中欧医疗健康'},
    {'code': '005827', 'name': '易方达蓝筹精选'},
    {'code': '001938', 'name': '中欧时代先锋'},
  ];
}
