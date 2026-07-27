import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../widgets/feature_ui_components.dart';
import 'add_review_page.dart';

class ReviewsFeedPage extends StatefulWidget {
  const ReviewsFeedPage({
    super.key,
    required this.userId,
    this.reviewService,
    this.onArtworkTap,
    this.onChanged,
  });

  final int userId;
  final ReviewService? reviewService;
  final ValueChanged<int>? onArtworkTap;
  final VoidCallback? onChanged;

  @override
  State<ReviewsFeedPage> createState() => ReviewsFeedPageState();
}

class ReviewsFeedPageState extends State<ReviewsFeedPage> {
  late ReviewService _reviewService;
  List<ReviewModel> _reviews = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewService =
        widget.reviewService ?? ReviewService(userId: widget.userId);
    _load();
  }

  @override
  void didUpdateWidget(covariant ReviewsFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.reviewService != widget.reviewService) {
      _reviewService =
          widget.reviewService ?? ReviewService(userId: widget.userId);
      _load();
    }
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reviews = await _reviewService.getAllReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your reviews could not be loaded.';
      });
    }
  }

  Future<void> _edit(ReviewModel review) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddReviewPage(
          userId: widget.userId,
          artworkId: review.artworkId,
          artworkTitle: review.artworkTitle,
          review: review,
          reviewService: _reviewService,
        ),
      ),
    );
    if (changed == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _delete(ReviewModel review) async {
    if (review.id == null) return;
    final confirmed = await showFeatureDeleteConfirmation(
      context,
      title: 'Delete review?',
      message:
          'This removes your review of ${review.artworkTitle ?? 'this work'}. The work will stay in your archive.',
    );
    if (!confirmed) return;
    try {
      await _reviewService.deleteReview(review.id!);
      if (!mounted) return;
      showFeatureMessage(context, 'Review deleted.');
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(
        context,
        'We could not delete that review.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: featureCream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FeaturePageBody(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
                    30,
                    MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: featureBrown,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your thoughts, ratings, and memories.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: featureMuted),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: FeatureAsyncError(message: _error!, onRetry: _load),
                )
              else if (_reviews.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FeatureEmptyState(
                    icon: Icons.rate_review_outlined,
                    title: 'Your review shelf is waiting',
                    message:
                        'Open a work from your archive and write the first reflection you want to remember.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
                    0,
                    MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
                    40,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final available = constraints.crossAxisExtent
                          .clamp(0, 1120)
                          .toDouble();
                      final columns = available >= 820 ? 2 : 1;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          mainAxisExtent: 280,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ReviewCard(
                            review: _reviews[index],
                            onOpenArtwork: widget.onArtworkTap == null
                                ? null
                                : () => widget.onArtworkTap!(
                                    _reviews[index].artworkId,
                                  ),
                            onEdit: () => _edit(_reviews[index]),
                            onDelete: () => _delete(_reviews[index]),
                          ),
                          childCount: _reviews.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onOpenArtwork,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewModel review;
  final VoidCallback? onOpenArtwork;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpenArtwork,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.reviewerName ?? 'Archive member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: featureBrown,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            review.artworkTitle ?? 'Untitled work',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: featureBrown,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _friendlyDate(review.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: featureMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FeatureRatingBadge(rating: review.rating),
                PopupMenuButton<_ReviewAction>(
                  tooltip: 'Review actions',
                  onSelected: (action) {
                    switch (action) {
                      case _ReviewAction.edit:
                        onEdit();
                      case _ReviewAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ReviewAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ReviewAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline, color: featureRust),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: featureRust),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Text(
                review.content,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: featureBrown.withValues(alpha: .82),
                  height: 1.55,
                ),
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (review.status != null)
                  FeaturePill(
                    label: review.status!.label,
                    icon: Icons.bookmark_outline_rounded,
                    color: featureGold,
                  ),
                FeaturePill(
                  label: review.isPublic ? 'Public' : 'Private',
                  icon: review.isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  color: review.isPublic ? featureGreen : featureMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

enum _ReviewAction { edit, delete }
