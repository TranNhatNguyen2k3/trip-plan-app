import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../statistics/data/statistics_repository.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import 'expenses_screen.dart';

enum _SplitMode { equal, custom }

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.tripId,
    this.expenseId,
  });

  final String tripId;
  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _shareControllers = {};

  String? _paidBy;
  final Set<String> _selectedMemberIds = {};
  ExpenseCategory _category = ExpenseCategory.other;
  _SplitMode _splitMode = _SplitMode.equal;
  DateTime _expenseDate = DateTime.now();
  bool _saving = false;
  bool _initialized = false;
  bool _editLoaded = false;
  String? _loadError;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amount {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  List<ExpenseShare> _buildShares(List<String> memberIds) {
    if (memberIds.isEmpty || _amount <= 0) return const [];
    if (_splitMode == _SplitMode.equal) {
      return splitEqually(_amount, memberIds)
          .map((e) => ExpenseShare(userId: e.userId, shareAmount: e.shareAmount))
          .toList();
    }
    return memberIds.map((id) {
      final raw = _shareControllers[id]?.text.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      return ExpenseShare(userId: id, shareAmount: int.tryParse(raw) ?? 0);
    }).toList();
  }

  bool get _sharesValid {
    final ids = _selectedMemberIds.toList();
    if (ids.isEmpty || _amount <= 0) return false;
    final shares = _buildShares(ids);
    return sharesSumToAmount(_amount, shares.map((s) => s.shareAmount));
  }

  void _ensureShareControllers(List<String> memberIds) {
    for (final id in memberIds) {
      _shareControllers.putIfAbsent(id, TextEditingController.new);
    }
  }

  void _applyEqualShares() {
    final ids = _selectedMemberIds.toList();
    if (ids.isEmpty || _amount <= 0) return;
    final splits = splitEqually(_amount, ids);
    for (final s in splits) {
      _shareControllers[s.userId]?.text = s.shareAmount.toString();
    }
  }

  void _initDefaults(List<TripMember> members, String? currentUserId) {
    if (_initialized) return;
    _initialized = true;

    final userId = currentUserId ?? (members.isNotEmpty ? members.first.userId : null);
    _paidBy = userId;
    _selectedMemberIds
      ..clear()
      ..addAll(members.map((m) => m.userId));
    _ensureShareControllers(members.map((m) => m.userId).toList());

    if (widget.isEditing) {
      Future.microtask(_loadExpenseForEdit);
    } else {
      _editLoaded = true;
    }
  }

  Future<void> _loadExpenseForEdit() async {
    try {
      final expense = await ref.read(expenseRepositoryProvider).getExpense(widget.expenseId!);
      if (!mounted) return;
      setState(() {
        _amountController.text = expense.amount.toString();
        _descriptionController.text = expense.description;
        _noteController.text = expense.note ?? '';
        _paidBy = expense.paidBy;
        _category = expense.category;
        _expenseDate = expense.expenseDate;
        _selectedMemberIds
          ..clear()
          ..addAll(expense.participants.map((p) => p.userId));
        _ensureShareControllers(_selectedMemberIds.toList());
        final equal = _isEqualSplit(expense);
        _splitMode = equal ? _SplitMode.equal : _SplitMode.custom;
        for (final p in expense.participants) {
          _shareControllers[p.userId]?.text = p.shareAmount.toString();
        }
        _editLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = mapErrorToMessage(e);
        _editLoaded = true;
      });
    }
  }

  bool _isEqualSplit(Expense expense) {
    if (expense.participants.isEmpty || expense.amount <= 0) return true;
    final ids = expense.participants.map((p) => p.userId).toList();
    final expected = splitEqually(expense.amount, ids);
    final map = {for (final p in expense.participants) p.userId: p.shareAmount};
    for (final e in expected) {
      if (map[e.userId] != e.shareAmount) return false;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _pickPayer(List<TripMember> members) async {
    final selected = await showAppBottomSheet<String>(
      context: context,
      title: 'Paid by',
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final name = member.profile?.displayName ?? 'Traveler';
          return ListTile(
            leading: AppAvatar(name: name, url: member.profile?.avatarUrl),
            title: Text(name),
            trailing: member.userId == _paidBy
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () => Navigator.pop(context, member.userId),
          );
        },
      ),
    );
    if (selected != null) setState(() => _paidBy = selected);
  }

  Future<void> _save(List<TripMember> members) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sharesValid || _paidBy == null) return;

    setState(() => _saving = true);
    try {
      final shares = _buildShares(_selectedMemberIds.toList());
      final repo = ref.read(expenseRepositoryProvider);
      if (widget.isEditing) {
        await repo.updateExpense(
          expenseId: widget.expenseId!,
          description: _descriptionController.text.trim(),
          amount: _amount,
          category: _category,
          paidBy: _paidBy!,
          expenseDate: _expenseDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          participants: shares,
        );
      } else {
        await repo.createExpense(
          tripId: widget.tripId,
          description: _descriptionController.text.trim(),
          amount: _amount,
          category: _category,
          paidBy: _paidBy!,
          expenseDate: _expenseDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          participants: shares,
        );
      }

      ref.invalidate(expensesProvider(widget.tripId));
      ref.invalidate(tripBalancesProvider(widget.tripId));
      ref.invalidate(tripStatisticsProvider(widget.tripId));
      if (widget.isEditing) {
        ref.invalidate(
          expenseProvider((tripId: widget.tripId, expenseId: widget.expenseId!)),
        );
      }
      HapticFeedback.lightImpact();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _memberName(List<TripMember> members, String? userId) {
    if (userId == null) return 'Select';
    for (final member in members) {
      if (member.userId == userId) {
        return member.profile?.displayName ?? 'Traveler';
      }
    }
    return 'Traveler';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripMembersProvider(widget.tripId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit expense' : 'Add expense'),
      ),
      body: membersAsync.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(tripMembersProvider(widget.tripId)),
        ),
        data: (members) {
          if (members.isEmpty) {
            return const AppErrorState(
              error: 'Add trip members before creating expenses.',
            );
          }

          _initDefaults(members, currentUser?.id);

          if (_loadError != null) {
            return AppErrorState(
              error: _loadError!,
              onRetry: () {
                setState(() {
                  _loadError = null;
                  _initialized = false;
                  _editLoaded = false;
                });
              },
            );
          }

          if (widget.isEditing && !_editLoaded) {
            return const AppLoading(message: 'Loading expense…');
          }

          final canSave = !_saving &&
              _amount > 0 &&
              _descriptionController.text.trim().isNotEmpty &&
              _paidBy != null &&
              _selectedMemberIds.isNotEmpty &&
              _sharesValid;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Text(
                  'Amount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: '₫',
                    border: InputBorder.none,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                    if (n == null || n <= 0) return 'Enter an amount';
                    return null;
                  },
                  onChanged: (_) {
                    if (_splitMode == _SplitMode.equal) _applyEqualShares();
                    setState(() {});
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'What was this for?',
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Paid by', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(name: _memberName(members, _paidBy)),
                  title: Text(_memberName(members, _paidBy)),
                  trailing: const Icon(Icons.keyboard_arrow_down),
                  onTap: () => _pickPayer(members),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Split between',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedMemberIds.length == members.length) {
                            _selectedMemberIds.clear();
                            if (_paidBy != null) _selectedMemberIds.add(_paidBy!);
                          } else {
                            _selectedMemberIds
                              ..clear()
                              ..addAll(members.map((m) => m.userId));
                          }
                          if (_splitMode == _SplitMode.equal) _applyEqualShares();
                        });
                      },
                      child: Text(
                        _selectedMemberIds.length == members.length
                            ? 'Clear'
                            : 'Everyone',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final member in members)
                      AppChip(
                        label: member.profile?.displayName ?? 'Traveler',
                        selected: _selectedMemberIds.contains(member.userId),
                        onTap: () {
                          setState(() {
                            if (_selectedMemberIds.contains(member.userId)) {
                              if (_selectedMemberIds.length > 1) {
                                _selectedMemberIds.remove(member.userId);
                              }
                            } else {
                              _selectedMemberIds.add(member.userId);
                              _ensureShareControllers([member.userId]);
                            }
                            if (_splitMode == _SplitMode.equal) {
                              _applyEqualShares();
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Split type', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<_SplitMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SplitMode.equal,
                      label: Text('Equal'),
                      icon: Icon(Icons.balance_outlined),
                    ),
                    ButtonSegment(
                      value: _SplitMode.custom,
                      label: Text('Custom'),
                      icon: Icon(Icons.tune),
                    ),
                  ],
                  selected: {_splitMode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _splitMode = value.first;
                      if (_splitMode == _SplitMode.equal) _applyEqualShares();
                    });
                  },
                ),
                if (_splitMode == _SplitMode.custom) ...[
                  const SizedBox(height: AppSpacing.md),
                  for (final id in _selectedMemberIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppTextField(
                        controller: _shareControllers[id],
                        label: _memberName(members, id),
                        keyboardType: TextInputType.number,
                        hint: '0',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  if (!_sharesValid && _amount > 0)
                    Text(
                      'Shares must add up to ${formatCurrency(_amount)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final cat in ExpenseCategory.values)
                      AppChip(
                        label: cat.label,
                        icon: categoryIcon(cat),
                        selected: _category == cat,
                        onTap: () => setState(() => _category = cat),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Date',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(formatDate(_expenseDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _noteController,
                  label: 'Note (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: widget.isEditing ? 'Save changes' : 'Save expense',
                  isLoading: _saving,
                  onPressed: canSave ? () => _save(members) : null,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}
