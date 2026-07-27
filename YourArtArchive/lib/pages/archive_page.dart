import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../services/artwork_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_card.dart';
import '../widgets/editorial_page.dart';
import '../widgets/empty_state.dart';

enum _ArchiveFilter {
  all('All'),
  inProgress('In Progress'),
  completed('Completed'),
  want('Want'),
  abandoned('Abandoned'),
  favorites('Favorites');

  const _ArchiveFilter(this.label);
  final String label;
}

class ArchivePage extends StatefulWidget {
  const ArchivePage({
    super.key,
    required this.artworkService,
    required this.onArtworkTap,
    required this.onAddArtwork,
  });

  final ArtworkService artworkService;
  final ValueChanged<ArtworkModel> onArtworkTap;
  final VoidCallback onAddArtwork;

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  _ArchiveFilter _filter = _ArchiveFilter.all;
  List<ArtworkModel> _all = const [];
  List<ArtworkModel> _visible = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ArchivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkService != widget.artworkService) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await widget.artworkService.getAllArtworks();
      if (!mounted) return;
      setState(() {
        _all = all;
        _visible = _applyFilter(all);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<ArtworkModel> _applyFilter(List<ArtworkModel> artworks) {
    return switch (_filter) {
      _ArchiveFilter.all => artworks,
      _ArchiveFilter.inProgress =>
        artworks
            .where((work) => work.status == ArtworkStatus.inProgress)
            .toList(growable: false),
      _ArchiveFilter.completed =>
        artworks
            .where((work) => work.status == ArtworkStatus.completed)
            .toList(growable: false),
      _ArchiveFilter.want =>
        artworks
            .where((work) => work.status == ArtworkStatus.want)
            .toList(growable: false),
      _ArchiveFilter.abandoned =>
        artworks
            .where((work) => work.status == ArtworkStatus.abandoned)
            .toList(growable: false),
      _ArchiveFilter.favorites =>
        artworks.where((work) => work.isFavorite).toList(growable: false),
    };
  }

  void _setFilter(_ArchiveFilter filter) {
    setState(() {
      _filter = filter;
      _visible = _applyFilter(_all);
    });
  }

  int _count(ArtworkStatus status) =>
      _all.where((artwork) => artwork.status == status).length;

  Future<void> _toggleFavorite(ArtworkModel artwork) async {
    if (artwork.id == null) return;
    try {
      await widget.artworkService.toggleFavorite(artwork.id!);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: EditorialPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Archive',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${_all.length} works, all in one place.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onAddArtwork,
                  icon: const Icon(Icons.add_rounded),
                  label: MediaQuery.sizeOf(context).width < 430
                      ? const Text('Add')
                      : const Text('Add work'),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _Stats(
              total: _all.length,
              inProgress: _count(ArtworkStatus.inProgress),
              completed: _count(ArtworkStatus.completed),
              favorites: _all.where((artwork) => artwork.isFavorite).length,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ArchiveFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _ArchiveFilter.values[index];
                  return ChoiceChip(
                    selected: _filter == filter,
                    onSelected: (_) => _setFilter(filter),
                    label: Text(filter.label),
                  );
                },
              ),
            ),
            const SizedBox(height: 27),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              EmptyState(
                title: 'Could not open your archive',
                message: _error!,
                icon: Icons.error_outline_rounded,
                actionLabel: 'Try again',
                onAction: _load,
              )
            else if (_visible.isEmpty)
              EmptyState(
                title: _filter == _ArchiveFilter.all
                    ? 'Your archive is empty'
                    : 'No ${_filter.label.toLowerCase()} works',
                message: _filter == _ArchiveFilter.all
                    ? 'Add your first work to start your personal collection.'
                    : 'Choose another filter or update a work in your archive.',
                actionLabel: 'Add a work',
                onAction: widget.onAddArtwork,
              )
            else
              ResponsiveGrid(
                children: _visible
                    .map(
                      (artwork) => ArtworkCard(
                        title: artwork.title,
                        creator: artwork.creator ?? 'Unknown creator',
                        category: artwork.category.label,
                        imageSource: artwork.imageUrl,
                        rating: artwork.rating,
                        status: artwork.status.label,
                        isFavorite: artwork.isFavorite,
                        onTap: () => widget.onArtworkTap(artwork),
                        onFavorite: () => _toggleFavorite(artwork),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.favorites,
  });

  final int total;
  final int inProgress;
  final int completed;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('All works', total, Icons.grid_view_rounded, AppColors.brown),
      ('In progress', inProgress, Icons.timelapse_rounded, AppColors.gold),
      ('Completed', completed, Icons.check_circle_outline, AppColors.success),
      ('Favorites', favorites, Icons.favorite_border, AppColors.danger),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth < 360 ? 1.8 : 2.3,
          ),
          itemBuilder: (context, index) {
            final value = values[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Icon(value.$3, color: value.$4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.$2.toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            value.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
