import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/artwork_model.dart';
import '../theme/app_theme.dart';
import 'archive_image.dart';
import 'form_fields.dart';

class ArtworkForm extends StatefulWidget {
  const ArtworkForm({
    super.key,
    required this.userId,
    required this.submitLabel,
    required this.onSubmit,
    this.initialArtwork,
    this.onCancel,
  });

  final int userId;
  final String submitLabel;
  final ArtworkModel? initialArtwork;
  final Future<void> Function(ArtworkModel artwork) onSubmit;
  final VoidCallback? onCancel;

  @override
  State<ArtworkForm> createState() => _ArtworkFormState();
}

class _ArtworkFormState extends State<ArtworkForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _creatorController;
  late final TextEditingController _yearController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageController;
  late final TextEditingController _tagsController;
  late ArtworkCategory _category;
  late ArtworkStatus _status;
  int? _rating;
  late bool _favorite;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final artwork = widget.initialArtwork;
    _titleController = TextEditingController(text: artwork?.title ?? '');
    _creatorController = TextEditingController(text: artwork?.creator ?? '');
    _yearController = TextEditingController(
      text: artwork?.year?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: artwork?.description ?? '',
    );
    _imageController = TextEditingController(text: artwork?.imageUrl ?? '');
    _tagsController = TextEditingController(
      text: artwork?.tags.join(', ') ?? '',
    );
    _category = artwork?.category ?? ArtworkCategory.book;
    _status = artwork?.status ?? ArtworkStatus.want;
    _rating = artwork?.rating?.round();
    _favorite = artwork?.isFavorite ?? false;
    _imageController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _imageController.removeListener(_refreshPreview);
    _titleController.dispose();
    _creatorController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final initial = widget.initialArtwork;
      final artwork = ArtworkModel(
        id: initial?.id,
        userId: widget.userId,
        title: _titleController.text.trim(),
        category: _category,
        creator: _nullWhenEmpty(_creatorController.text),
        year: int.tryParse(_yearController.text.trim()),
        description: _nullWhenEmpty(_descriptionController.text),
        imageUrl: _nullWhenEmpty(_imageController.text),
        status: _status,
        rating: _rating?.toDouble(),
        tags: _parseTags(_tagsController.text),
        isFavorite: _favorite,
        createdAt: initial?.createdAt,
      );
      await widget.onSubmit(artwork);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(
        () => _error = message.isEmpty
            ? 'We could not save this work. Try again.'
            : message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final preview = SizedBox(
                height: 250,
                child: ArchiveImage(
                  source: _imageController.text.trim(),
                  category: _category.label,
                ),
              );
              final fields = FormSection(
                title: 'The work',
                caption:
                    'Start with the details you know. Only a title is required.',
                children: [
                  AppTextField(
                    controller: _titleController,
                    label: 'Title',
                    hint: 'The Women',
                    prefixIcon: Icons.title_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a title'
                        : null,
                  ),
                  AppTextField(
                    controller: _creatorController,
                    label: 'Creator',
                    hint: 'Author, director, studio...',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  AppDropdown<ArtworkCategory>(
                    label: 'Category',
                    value: _category,
                    items: ArtworkCategory.values,
                    labelFor: (value) => value.label,
                    prefixIcon: Icons.category_outlined,
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  AppTextField(
                    controller: _yearController,
                    label: 'Year',
                    hint: '2024',
                    prefixIcon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final year = int.tryParse(text);
                      if (year == null || year < 1000 || year > 2100) {
                        return 'Enter a year between 1000 and 2100';
                      }
                      return null;
                    },
                  ),
                ],
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [preview, const SizedBox(height: 28), fields],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 210, child: preview),
                  const SizedBox(width: 28),
                  Expanded(child: fields),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          FormSection(
            title: 'Your experience',
            children: [
              AppDropdown<ArtworkStatus>(
                label: 'Status',
                value: _status,
                items: ArtworkStatus.values,
                labelFor: (value) => value.label,
                prefixIcon: Icons.timelapse_rounded,
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              RatingDropdown(
                value: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
              SwitchListTile.adaptive(
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Favorite work'),
                subtitle: const Text('Show it in your Favorites collection.'),
                secondary: Icon(
                  _favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _favorite ? AppColors.danger : AppColors.muted,
                ),
              ),
            ],
          ),
          FormSection(
            title: 'More details',
            children: [
              AppTextField(
                controller: _descriptionController,
                label: 'Description or notes',
                hint: 'What is this work about?',
                prefixIcon: Icons.notes_rounded,
                minLines: 4,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
              ),
              AppTextField(
                controller: _imageController,
                label: 'Image URL or local asset',
                hint: 'https://example.com/cover.jpg',
                prefixIcon: Icons.image_outlined,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty || !text.contains('://')) return null;
                  final uri = Uri.tryParse(text);
                  if (uri == null ||
                      !uri.hasScheme ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return 'Use a valid HTTP or HTTPS image URL';
                  }
                  return null;
                },
              ),
              AppTextField(
                controller: _tagsController,
                label: 'Tags',
                hint: 'historical, emotional, favorite',
                prefixIcon: Icons.sell_outlined,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
            const SizedBox(height: 18),
          ],
          FormActions(
            primaryLabel: widget.submitLabel,
            onPrimary: _submit,
            onSecondary: widget.onCancel,
            busy: _busy,
          ),
        ],
      ),
    );
  }

  String? _nullWhenEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _parseTags(String raw) {
    final seen = <String>{};
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
        .toList(growable: false);
  }
}
