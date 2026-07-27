import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../services/artwork_service.dart';
import '../widgets/artwork_card.dart';
import '../widgets/editorial_page.dart';
import '../widgets/empty_state.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.artworkService,
    required this.onArtworkTap,
    this.initialCategory,
    this.onAddArtwork,
  });

  final ArtworkService artworkService;
  final ValueChanged<ArtworkModel> onArtworkTap;
  final ArtworkCategory? initialCategory;
  final VoidCallback? onAddArtwork;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();
  ArtworkCategory? _category;
  List<ArtworkModel> _artworks = const [];
  bool _loading = true;
  String? _error;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _load();
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory) {
      _category = widget.initialCategory;
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestNumber;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchController.text.trim();
      List<ArtworkModel> results;
      if (query.isNotEmpty) {
        results = await widget.artworkService.searchArtworks(query);
        if (_category != null) {
          results = results
              .where((artwork) => artwork.category == _category)
              .toList(growable: false);
        }
      } else if (_category != null) {
        results = await widget.artworkService.filterByCategory(_category!);
      } else {
        results = await widget.artworkService.getAllArtworks();
      }
      if (!mounted || request != _requestNumber) return;
      setState(() {
        _artworks = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _requestNumber) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _toggleFavorite(ArtworkModel artwork) async {
    if (artwork.id == null) return;
    await widget.artworkService.toggleFavorite(artwork.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return EditorialPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Discover', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 7),
          Text(
            'Search and filter the works in your personal archive.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (_) => _load(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Title, creator, or tag...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) {
                      setState(() => _category = null);
                      _load();
                    },
                  ),
                ),
                ...ArtworkCategory.values.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) {
                        setState(() => _category = category);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recommendations — ${_artworks.length} ${_artworks.length == 1 ? 'result' : 'results'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load your archive',
              message: _error!,
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Try again',
              onAction: _load,
            )
          else if (_artworks.isEmpty)
            EmptyState(
              title: 'No matching works',
              message:
                  'Try a different search or category, or add a new work to your archive.',
              icon: Icons.search_off_rounded,
              actionLabel: 'Add a work',
              onAction: widget.onAddArtwork,
            )
          else
            ResponsiveGrid(
              children: _artworks
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
    );
  }
}
