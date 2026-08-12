import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/journal_repository.dart';

class JournalFormScreen extends ConsumerStatefulWidget {
  const JournalFormScreen({
    super.key,
    required this.tripId,
    this.entryId,
  });

  final String tripId;
  final String? entryId;

  bool get isEditing => entryId != null;

  @override
  ConsumerState<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends ConsumerState<JournalFormScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  DateTime _visitedAt = DateTime.now();
  final List<String> _localPhotoPaths = [];
  List<PhotoUploadItem> _uploadItems = [];
  bool _saving = false;
  bool _uploading = false;
  bool _loadingEntry = false;
  String? _loadError;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadEntry();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    setState(() => _loadingEntry = true);
    try {
      final entry =
          await ref.read(journalRepositoryProvider).getEntry(widget.entryId!);
      if (!mounted) return;
      setState(() {
        _titleController.text = entry.title ?? '';
        _locationController.text = entry.locationName ?? '';
        _descriptionController.text = entry.description ?? '';
        _visitedAt = entry.visitedAt;
        _loadingEntry = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = mapErrorToMessage(e);
        _loadingEntry = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _visitedAt = picked);
  }

  Future<void> _addPhotos() async {
    final remaining = AppConstants.maxPhotosPerEntry - _localPhotoPaths.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${AppConstants.maxPhotosPerEntry} photos'),
        ),
      );
      return;
    }

    final source = await showAppBottomSheet<ImageSource>(
      context: context,
      title: 'Add photos',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;

    try {
      if (source == ImageSource.camera) {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (file != null) {
          setState(() => _localPhotoPaths.add(file.path));
        }
      } else {
        final files = await _picker.pickMultiImage(
          imageQuality: 90,
          limit: remaining,
        );
        if (files.isNotEmpty) {
          setState(() {
            _localPhotoPaths.addAll(files.map((f) => f.path).take(remaining));
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    setState(() => _saving = true);

    final repo = ref.read(journalRepositoryProvider);
    try {
      late final String entryId;
      if (widget.isEditing) {
        final updated = await repo.updateEntry(
          entryId: widget.entryId!,
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          locationName: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          visitedAt: _visitedAt,
        );
        entryId = updated.id;
      } else {
        final created = await repo.createEntry(
          tripId: widget.tripId,
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          locationName: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          visitedAt: _visitedAt,
        );
        entryId = created.id;
      }

      if (_localPhotoPaths.isNotEmpty) {
        setState(() {
          _uploading = true;
          _uploadItems = _localPhotoPaths
              .map(
                (p) => PhotoUploadItem(
                  localPath: p,
                  status: PhotoUploadStatus.waiting,
                ),
              )
              .toList();
          _uploadProgress = 0;
        });

        await repo.uploadPhotos(
          tripId: widget.tripId,
          entryId: entryId,
          items: _uploadItems,
          onProgress: () {
            if (!mounted) return;
            final done = _uploadItems
                .where(
                  (i) =>
                      i.status == PhotoUploadStatus.done ||
                      i.status == PhotoUploadStatus.failed,
                )
                .length;
            setState(() {
              _uploadProgress =
                  _uploadItems.isEmpty ? 1 : done / _uploadItems.length;
            });
          },
        );

        final failed =
            _uploadItems.where((i) => i.status == PhotoUploadStatus.failed);
        if (failed.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${failed.length} photo(s) failed to upload. You can try again later.',
              ),
            ),
          );
        }
      }

      ref.invalidate(journalEntriesProvider(widget.tripId));
      ref.invalidate(journalSummaryProvider(widget.tripId));
      ref.invalidate(journalEntryProvider(entryId));
      HapticFeedback.lightImpact();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEntry) {
      return const Scaffold(body: AppLoading(message: 'Loading memory…'));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memory')),
        body: AppErrorState(
          error: _loadError!,
          onRetry: () {
            setState(() => _loadError = null);
            _loadEntry();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit memory' : 'New memory'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Text('Photos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _localPhotoPaths.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: InkWell(
                        onTap: _uploading ? null : _addPhotos,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined),
                            SizedBox(height: 4),
                            Text('Add'),
                          ],
                        ),
                      ),
                    );
                  }
                  final path = _localPhotoPaths[index - 1];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploading
                                ? null
                                : () => setState(
                                      () => _localPhotoPaths.removeAt(index - 1),
                                    ),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_uploading && index - 1 < _uploadItems.length)
                        _UploadOverlay(item: _uploadItems[index - 1]),
                    ],
                  );
                },
              ),
              if (_uploading) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Uploading photos… ${(_uploadProgress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'Where was this?',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Give this memory a name',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'What happened?',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Date',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(formatDate(_visitedAt)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _uploading ? null : _pickDate,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: widget.isEditing ? 'Save changes' : 'Save memory',
                isLoading: _saving || _uploading,
                onPressed: (_saving || _uploading) ? null : _save,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
          if (_uploading)
            const ModalBarrier(dismissible: false, color: Colors.black26),
        ],
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.item});

  final PhotoUploadItem item;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black45,
      child: Center(
        child: switch (item.status) {
          PhotoUploadStatus.waiting => const Icon(
              Icons.hourglass_empty,
              color: Colors.white,
            ),
          PhotoUploadStatus.uploading => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          PhotoUploadStatus.done => const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
          PhotoUploadStatus.failed => const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
        },
      ),
    );
  }
}
