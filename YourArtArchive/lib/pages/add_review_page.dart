import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../widgets/feature_ui_components.dart';

class AddReviewPage extends StatefulWidget {
  const AddReviewPage({
    super.key,
    required this.userId,
    required this.artworkId,
    this.artworkTitle,
    this.review,
    this.reviewService,
    this.onSaved,
  });

  final int userId;
  final int artworkId;
  final String? artworkTitle;
  final ReviewModel? review;
  final ReviewService? reviewService;
  final ValueChanged<ReviewModel>? onSaved;

  bool get isEditing => review != null;

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  late final ReviewService _reviewService;
  late int _rating;
  late ArtworkStatus _status;
  late bool _isPublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reviewService =
        widget.reviewService ?? ReviewService(userId: widget.userId);
    _contentController = TextEditingController(
      text: widget.review?.content ?? '',
    );
    _rating = (widget.review?.rating.round() ?? 8).clamp(1, 10);
    _status = widget.review?.status ?? ArtworkStatus.completed;
    _isPublic = widget.review?.isPublic ?? true;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final original = widget.review;
    final review = ReviewModel(
      id: original?.id,
      userId: widget.userId,
      artworkId: widget.artworkId,
      content: _contentController.text.trim(),
      rating: _rating.toDouble(),
      status: _status,
      isPublic: _isPublic,
      createdAt: original?.createdAt,
      artworkTitle: widget.artworkTitle ?? original?.artworkTitle,
    );

    try {
      final saved = widget.isEditing
          ? await _reviewService.updateReview(review)
          : await _reviewService.createReview(review);
      if (!mounted) return;
      widget.onSaved?.call(saved);
      showFeatureMessage(
        context,
        widget.isEditing ? 'Review updated.' : 'Review posted.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showFeatureMessage(
        context,
        'We could not save your review. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit review' : 'Write a review'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: FeaturePageBody(
            maxWidth: 680,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((widget.artworkTitle ?? '').trim().isNotEmpty) ...[
                    Text(
                      widget.artworkTitle!,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: featureBrown,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEditing
                          ? 'Refine your thoughts and rating.'
                          : 'Capture what stayed with you.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: featureMuted),
                    ),
                    const SizedBox(height: 24),
                  ],
                  FeaturePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 520;
                            final rating = _ratingField();
                            final status = _statusField();
                            if (!wide) {
                              return Column(
                                children: [
                                  rating,
                                  const SizedBox(height: 16),
                                  status,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: rating),
                                const SizedBox(width: 16),
                                Expanded(child: status),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _contentController,
                          minLines: 6,
                          maxLines: 10,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Your review',
                            hintText: 'What did you notice, feel, or remember?',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Write a few words before posting.';
                            }
                            return null;
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isPublic,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _isPublic = value),
                          title: const Text('Public review'),
                          subtitle: Text(
                            _isPublic
                                ? 'Visible wherever public reviews are shown.'
                                : 'Only visible inside your own archive.',
                          ),
                          secondary: Icon(
                            _isPublic
                                ? Icons.public_rounded
                                : Icons.lock_outline_rounded,
                            color: featureGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.isEditing
                                ? Icons.save_outlined
                                : Icons.send_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : widget.isEditing
                          ? 'Save changes'
                          : 'Post review',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingField() {
    return DropdownButtonFormField<int>(
      initialValue: _rating,
      decoration: const InputDecoration(
        labelText: 'Rating',
        prefixIcon: Icon(Icons.star_outline_rounded),
      ),
      items: [
        for (var value = 1; value <= 10; value++)
          DropdownMenuItem(value: value, child: Text('$value / 10')),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _rating = value ?? 8),
    );
  }

  Widget _statusField() {
    return DropdownButtonFormField<ArtworkStatus>(
      initialValue: _status,
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.bookmark_outline_rounded),
      ),
      items: ArtworkStatus.values
          .map(
            (status) =>
                DropdownMenuItem(value: status, child: Text(status.label)),
          )
          .toList(growable: false),
      onChanged: _saving
          ? null
          : (value) => setState(() => _status = value ?? _status),
    );
  }
}
