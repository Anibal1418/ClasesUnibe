import 'dart:async';

import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/list_model.dart';
import '../models/review_model.dart';
import '../services/artwork_service.dart';
import '../services/list_service.dart';
import '../services/review_service.dart';
import '../widgets/feature_ui_components.dart';
import 'add_review_page.dart';
import 'edit_artwork_page.dart';
import 'lists_page.dart';

typedef ArtworkEditCallback = FutureOr<bool?> Function(ArtworkModel artwork);

class ArtworkDetailPage extends StatefulWidget {
  const ArtworkDetailPage({
    super.key,
    required this.userId,
    required this.artworkId,
    this.initialArtwork,
    this.artworkService,
    this.reviewService,
    this.listService,
    this.onEdit,
    this.onDeleted,
    this.onChanged,
  });

  final int userId;
  final int artworkId;
  final ArtworkModel? initialArtwork;
  final ArtworkService? artworkService;
  final ReviewService? reviewService;
  final ListService? listService;
  final ArtworkEditCallback? onEdit;
  final VoidCallback? onDeleted;
  final VoidCallback? onChanged;

  @override
  State<ArtworkDetailPage> createState() => _ArtworkDetailPageState();
}

class _ArtworkDetailPageState extends State<ArtworkDetailPage> {
  late ArtworkService _artworkService;
  late ReviewService _reviewService;
  late ListService _listService;
  ArtworkModel? _artwork;
  List<ReviewModel> _reviews = const [];
  List<ListModel> _lists = const [];
  bool _loading = true;
  bool _favoriteBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _artwork = widget.initialArtwork;
    _resolveServices();
    _load(showSpinner: _artwork == null);
  }

  @override
  void didUpdateWidget(covariant ArtworkDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.artworkId != widget.artworkId ||
        oldWidget.artworkService != widget.artworkService ||
        oldWidget.reviewService != widget.reviewService ||
        oldWidget.listService != widget.listService) {
      _resolveServices();
      _artwork = widget.initialArtwork;
      _load(showSpinner: _artwork == null);
    }
  }

  void _resolveServices() {
    _artworkService =
        widget.artworkService ?? ArtworkService(userId: widget.userId);
    _reviewService =
        widget.reviewService ?? ReviewService(userId: widget.userId);
    _listService = widget.listService ?? ListService(userId: widget.userId);
  }

  Future<void> _load({bool showSpinner = false}) async {
    if (mounted) {
      setState(() {
        _loading = showSpinner;
        _error = null;
      });
    }
    try {
      final artwork = await _artworkService.getArtworkById(widget.artworkId);
      if (artwork == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'This work is no longer in your archive.';
        });
        return;
      }
      final reviews = await _reviewService.getReviewsByArtworkId(
        widget.artworkId,
      );
      final lists = await _listService.getAllLists();
      if (!mounted) return;
      setState(() {
        _artwork = artwork;
        _reviews = reviews;
        _lists = lists;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This work could not be loaded.';
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      final updated = await _artworkService.toggleFavorite(widget.artworkId);
      if (!mounted) return;
      setState(() {
        _artwork = updated;
        _favoriteBusy = false;
      });
      widget.onChanged?.call();
      showFeatureMessage(
        context,
        updated.isFavorite ? 'Added to favorites.' : 'Removed from favorites.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _favoriteBusy = false);
      showFeatureMessage(
        context,
        'We could not update your favorites.',
        error: true,
      );
    }
  }

  Future<void> _writeReview([ReviewModel? review]) async {
    final artwork = _artwork;
    if (artwork == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddReviewPage(
          userId: widget.userId,
          artworkId: widget.artworkId,
          artworkTitle: artwork.title,
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

  Future<void> _deleteReview(ReviewModel review) async {
    if (review.id == null) return;
    final confirmed = await showFeatureDeleteConfirmation(
      context,
      title: 'Delete review?',
      message:
          'This reflection will be removed permanently. The work will stay in your archive.',
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

  Future<void> _edit() async {
    final artwork = _artwork;
    if (artwork == null) return;
    final callback = widget.onEdit;
    bool? changed;
    if (callback != null) {
      changed = await Future<bool?>.value(callback(artwork));
    } else {
      changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EditArtworkPage(
            artworkService: _artworkService,
            artwork: artwork,
            onSaved: (saved) => Navigator.of(context).pop(true),
          ),
        ),
      );
    }
    if (!mounted) return;
    if (changed == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _deleteArtwork() async {
    final artwork = _artwork;
    if (artwork == null) return;
    final confirmed = await showFeatureDeleteConfirmation(
      context,
      title: 'Remove “${artwork.title}”?',
      message:
          'This permanently removes the work, its reviews, and its list memberships from your archive.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    try {
      await _artworkService.deleteArtwork(widget.artworkId);
      if (!mounted) return;
      widget.onDeleted?.call();
      widget.onChanged?.call();
      showFeatureMessage(context, 'Work removed from your archive.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(
        context,
        'We could not remove this work.',
        error: true,
      );
    }
  }

  Future<void> _addToList() async {
    final artwork = _artwork;
    final artworkId = artwork?.id;
    if (artwork == null || artworkId == null) return;
    if (_lists.isEmpty) {
      final create =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(
                Icons.collections_bookmark_outlined,
                color: featureGold,
              ),
              title: const Text('Create your first list'),
              content: const Text(
                'Lists help you gather works around themes, moods, and ideas.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open lists'),
                ),
              ],
            ),
          ) ??
          false;
      if (!create || !mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ListsPage(
            userId: widget.userId,
            listService: _listService,
            artworkService: _artworkService,
          ),
        ),
      );
      await _load();
      return;
    }

    try {
      final membership = await Future.wait(
        _lists.map(
          (list) => _listService.isArtworkInList(
            listId: list.id!,
            artworkId: artworkId,
          ),
        ),
      );
      final available = <ListModel>[];
      for (var index = 0; index < _lists.length; index++) {
        if (!membership[index]) available.add(_lists[index]);
      }
      if (!mounted) return;
      if (available.isEmpty) {
        showFeatureMessage(
          context,
          'This work is already included in all your lists.',
        );
        return;
      }
      final listId = await showDialog<int>(
        context: context,
        builder: (_) => _ListPickerDialog(lists: available),
      );
      if (listId == null) return;
      await _listService.addArtworkToList(listId: listId, artworkId: artworkId);
      if (!mounted) return;
      showFeatureMessage(context, 'Added to list.');
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(
        context,
        'We could not update your lists.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final artwork = _artwork;
    return Scaffold(
      backgroundColor: featureCream,
      appBar: AppBar(
        title: Text(artwork?.title ?? 'Work details'),
        actions: [
          if (artwork != null)
            IconButton(
              tooltip: artwork.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: _favoriteBusy ? null : _toggleFavorite,
              icon: Icon(
                artwork.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: artwork.isFavorite ? featureRust : null,
              ),
            ),
          if (artwork != null)
            PopupMenuButton<_ArtworkAction>(
              tooltip: 'Work actions',
              onSelected: (action) {
                switch (action) {
                  case _ArtworkAction.edit:
                    _edit();
                  case _ArtworkAction.delete:
                    _deleteArtwork();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ArtworkAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit work'),
                  ),
                ),
                PopupMenuItem(
                  value: _ArtworkAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: featureRust),
                    title: Text(
                      'Remove from archive',
                      style: TextStyle(color: featureRust),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading && artwork == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && artwork == null
            ? FeatureAsyncError(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: _buildContent(artwork!),
              ),
      ),
    );
  }

  Widget _buildContent(ArtworkModel artwork) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: FeaturePageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArtworkHero(artwork: artwork),
                const SizedBox(height: 20),
                _ActionPanel(
                  favorite: artwork.isFavorite,
                  favoriteBusy: _favoriteBusy,
                  onFavorite: _toggleFavorite,
                  onReview: _writeReview,
                  onEdit: _edit,
                  onAddToList: _addToList,
                  onDelete: _deleteArtwork,
                ),
                const SizedBox(height: 26),
                if ((artwork.description ?? '').trim().isNotEmpty) ...[
                  Text(
                    'Synopsis',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: featureBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    artwork.description!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: featureBrown.withValues(alpha: .78),
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                if (artwork.tags.isNotEmpty) ...[
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: featureBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in artwork.tags)
                        FeaturePill(
                          label: tag,
                          icon: Icons.tag_rounded,
                          color: featureGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your reviews',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: featureBrown,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _writeReview,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Write review'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  FeaturePanel(
                    child: FeatureEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: 'No reviews yet',
                      message:
                          'Capture the details and feelings you want to remember.',
                      actionLabel: 'Write review',
                      onAction: _writeReview,
                    ),
                  )
                else
                  ..._reviews.map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DetailReviewCard(
                        review: review,
                        onEdit: () => _writeReview(review),
                        onDelete: () => _deleteReview(review),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtworkHero extends StatelessWidget {
  const _ArtworkHero({required this.artwork});

  final ArtworkModel artwork;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final image = FeatureNetworkArtworkImage(
          imageUrl: artwork.imageUrl,
          title: artwork.title,
          height: wide ? 390 : 320,
          width: wide ? 280 : double.infinity,
          borderRadius: BorderRadius.circular(24),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FeaturePill(
                  label: artwork.category.label,
                  icon: Icons.local_offer_outlined,
                  color: featureGold,
                ),
                FeaturePill(
                  label: artwork.status.label,
                  icon: Icons.bookmark_outline_rounded,
                  color: _statusColor(artwork.status),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              artwork.title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: featureBrown,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [
                if ((artwork.creator ?? '').trim().isNotEmpty) artwork.creator!,
                if (artwork.year != null) '${artwork.year}',
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: featureMuted),
            ),
            if (artwork.rating != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  FeatureRatingBadge(rating: artwork.rating!),
                  const SizedBox(width: 10),
                  Text(
                    'Your latest rating',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: featureMuted),
                  ),
                ],
              ),
            ],
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [image, const SizedBox(height: 24), details],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            image,
            const SizedBox(width: 36),
            Expanded(child: details),
          ],
        );
      },
    );
  }

  static Color _statusColor(ArtworkStatus status) {
    return switch (status) {
      ArtworkStatus.inProgress => featureRust,
      ArtworkStatus.completed => featureGreen,
      ArtworkStatus.want => featureGold,
      ArtworkStatus.abandoned => featureMuted,
    };
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.favorite,
    required this.favoriteBusy,
    required this.onFavorite,
    required this.onReview,
    required this.onEdit,
    required this.onAddToList,
    required this.onDelete,
  });

  final bool favorite;
  final bool favoriteBusy;
  final VoidCallback onFavorite;
  final VoidCallback onReview;
  final VoidCallback onEdit;
  final VoidCallback onAddToList;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = [
            (
              label: favorite ? 'Favorited' : 'Favorite',
              icon: favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              callback: favoriteBusy ? null : onFavorite,
              destructive: false,
            ),
            (
              label: 'Write review',
              icon: Icons.rate_review_outlined,
              callback: onReview,
              destructive: false,
            ),
            (
              label: 'Edit work',
              icon: Icons.edit_outlined,
              callback: onEdit,
              destructive: false,
            ),
            (
              label: 'Add to list',
              icon: Icons.playlist_add_rounded,
              callback: onAddToList,
              destructive: false,
            ),
            (
              label: 'Remove',
              icon: Icons.delete_outline_rounded,
              callback: onDelete,
              destructive: true,
            ),
          ];
          final columns = constraints.maxWidth >= 780
              ? 5
              : constraints.maxWidth >= 440
              ? 3
              : 2;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          final desktop = constraints.maxWidth >= 780;
          Widget buttonFor(
            ({
              String label,
              IconData icon,
              VoidCallback? callback,
              bool destructive,
            })
            action, {
            double? width,
          }) {
            return SizedBox(
              width: width,
              child: OutlinedButton.icon(
                onPressed: action.callback,
                icon: Icon(action.icon, size: 19),
                label: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: action.destructive
                      ? featureRust
                      : featureBrown,
                  side: BorderSide(
                    color: action.destructive
                        ? featureRust.withValues(alpha: .28)
                        : featureBrown.withValues(alpha: .13),
                  ),
                ),
              ),
            );
          }

          if (desktop) {
            return Row(
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final action in actions.take(4))
                        buttonFor(action, width: 158),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                buttonFor(actions.last, width: 150),
              ],
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions) buttonFor(action, width: width),
            ],
          );
        },
      ),
    );
  }
}

class _DetailReviewCard extends StatelessWidget {
  const _DetailReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewModel review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: featureGold.withValues(alpha: .18),
                child: Text(
                  _initials(review.reviewerName),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: featureBrown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.reviewerName ?? 'Archive member',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: featureBrown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FeatureRatingBadge(rating: review.rating),
              const SizedBox(width: 10),
              if (review.status != null)
                Text(
                  review.status!.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: featureMuted),
                )
              else
                const SizedBox.shrink(),
              FeaturePill(
                label: review.isPublic ? 'Public' : 'Private',
                icon: review.isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                color: review.isPublic ? featureGreen : featureMuted,
              ),
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
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: featureRust,
                      ),
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
          Text(
            review.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: featureBrown.withValues(alpha: .8),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? 'Archive member')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'A' : initials;
  }
}

class _ListPickerDialog extends StatelessWidget {
  const _ListPickerDialog({required this.lists});

  final List<ListModel> lists;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to a list'),
      content: SizedBox(
        width: 500,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: lists.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final list = lists[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: const Icon(
                Icons.collections_bookmark_outlined,
                color: featureGold,
              ),
              title: Text(list.title),
              subtitle: Text(
                '${list.artworkCount} ${list.artworkCount == 1 ? 'work' : 'works'} · ${list.isPublic ? 'Public' : 'Private'}',
              ),
              trailing: const Icon(Icons.add_circle_outline_rounded),
              onTap: () => Navigator.pop(context, list.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

enum _ArtworkAction { edit, delete }

enum _ReviewAction { edit, delete }
