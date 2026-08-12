import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/trip_repository.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate ?? DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final budgetRaw = _budgetController.text.replaceAll(RegExp(r'[^\d]'), '');
      final budget = budgetRaw.isEmpty ? null : int.tryParse(budgetRaw);
      final trip = await ref.read(tripRepositoryProvider).createTrip(
            name: _nameController.text.trim(),
            destination: _destinationController.text.trim().isEmpty
                ? null
                : _destinationController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            currency: AppConstants.defaultCurrency,
            budgetAmount: budget,
          );
      ref.invalidate(tripsProvider);
      if (!mounted) return;
      context.go('/trips/${trip.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapErrorToMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = formatDateRange(_startDate, _endDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New trip'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Text(
                'Where to next?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add a name, destination, and dates. You can invite friends after.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _nameController,
                label: 'Trip name',
                hint: 'Da Lat 2026',
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.luggage_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a trip name';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _destinationController,
                label: 'Destination',
                hint: 'City or region',
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Dates', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStart,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        _startDate == null
                            ? 'Start'
                            : formatDate(_startDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _endDate == null ? 'End' : formatDate(_endDate!),
                      ),
                    ),
                  ),
                ],
              ),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(dateLabel, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Optional notes for the group',
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _budgetController,
                label: 'Trip Budget',
                hint: '5,000,000 ₫ (optional)',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Currency: ${AppConstants.defaultCurrency}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Create trip',
                icon: Icons.flight_takeoff_rounded,
                onPressed: _submit,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
