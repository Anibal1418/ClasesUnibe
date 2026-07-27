import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/user_model.dart';
import '../services/artwork_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_card.dart';
import '../widgets/editorial_page.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.artworkService,
    required this.onArtworkTap,
    this.onDiscover,
    this.onArchive,
    this.onAddArtwork,
    this.onCategorySelected,
  });

  final UserModel user;
  final ArtworkService artworkService;
  final ValueChanged<ArtworkModel> onArtworkTap;
  final VoidCallback? onDiscover;
  final VoidCallback? onArchive;
  final VoidCallback? onAddArtwork;
  final ValueChanged<ArtworkCategory>? onCategorySelected;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  List<ArtworkModel> _continueExploring = const [];
  List<ArtworkModel> _recent = const [];
  List<ArtworkModel> _favorites = const [];
  List<ArtworkModel>? _searchResults;
  int _total = 0;
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.artworkService != widget.artworkService) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<List<ArtworkModel>>([
        widget.artworkService.getContinueExploring(limit: 6),
        widget.artworkService.getRecentlyAdded(limit: 8),
        widget.artworkService.getFavorites(),
        widget.artworkService.getAllArtworks(),
      ]);
      if (!mounted) return;
      setState(() {
        _continueExploring = results[0];
        _recent = results[1];
        _favorites = results[2];
        _total = results[3].length;
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

  Future<void> _search([String? submitted]) async {
    final query = (submitted ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.artworkService.searchArtworks(query);
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _toggleFavorite(ArtworkModel artwork) async {
    if (artwork.id == null) return;
    try {
      await widget.artworkService.toggleFavorite(artwork.id!);
      await _load();
      if (_searchResults != null) await _search();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: EditorialPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              name: widget.user.name,
              total: _total,
              favorites: _favorites.length,
              onAdd: widget.onAddArtwork,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: (value) {
                if (value.trim().isEmpty && _searchResults != null) {
                  setState(() => _searchResults = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search your books, movies, games, and more...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: () {
                          if (_searchController.text.isEmpty) return;
                          _searchController.clear();
                          setState(() => _searchResults = null);
                        },
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 17),
            _CategoryStrip(
              onSelected: (category) {
                if (widget.onCategorySelected != null) {
                  widget.onCategorySelected!(category);
                } else {
                  widget.onDiscover?.call();
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              _ErrorBanner(message: _error!, onRetry: _load),
            ],
            if (_searchResults != null) ...[
              const SizedBox(height: 32),
              SectionHeader(
                title: 'Search results',
                eyebrow:
                    '${_searchResults!.length} ${_searchResults!.length == 1 ? 'work' : 'works'}',
                actionLabel: 'Clear',
                onAction: () {
                  _searchController.clear();
                  setState(() => _searchResults = null);
                },
              ),
              const SizedBox(height: 14),
              if (_searchResults!.isEmpty)
                EmptyState(
                  title: 'No works found',
                  message:
                      'Try another title or creator, or add this work to your archive.',
                  icon: Icons.search_off_rounded,
                  actionLabel: 'Add a work',
                  onAction: widget.onAddArtwork,
                )
              else
                _ArtworkGrid(
                  artworks: _searchResults!,
                  onTap: widget.onArtworkTap,
                  onFavorite: _toggleFavorite,
                ),
            ] else ...[
              const SizedBox(height: 34),
              SectionHeader(
                title: 'Continue exploring',
                eyebrow: 'Your current stories',
                actionLabel: 'See archive',
                onAction: widget.onArchive,
              ),
              const SizedBox(height: 14),
              if (_continueExploring.isEmpty)
                EmptyState(
                  title: 'Nothing in progress yet',
                  message:
                      'Choose a work and mark it In Progress to keep it close.',
                  actionLabel: 'Explore your archive',
                  onAction: widget.onDiscover,
                )
              else
                _ArtworkGrid(
                  artworks: _continueExploring,
                  onTap: widget.onArtworkTap,
                  onFavorite: _toggleFavorite,
                ),
              const SizedBox(height: 38),
              SectionHeader(
                title: 'Recently added',
                actionLabel: 'See all',
                onAction: widget.onArchive,
              ),
              const SizedBox(height: 14),
              if (_recent.isEmpty)
                EmptyState(
                  title: 'Your archive is ready',
                  message:
                      'Add your first work and start recording the stories that matter.',
                  actionLabel: 'Add a work',
                  onAction: widget.onAddArtwork,
                )
              else
                _ArtworkGrid(
                  artworks: _recent,
                  onTap: widget.onArtworkTap,
                  onFavorite: _toggleFavorite,
                ),
              if (_favorites.isNotEmpty) ...[
                const SizedBox(height: 38),
                SectionHeader(
                  title: 'Favorites',
                  actionLabel: 'See all',
                  onAction: widget.onArchive,
                ),
                const SizedBox(height: 14),
                _ArtworkGrid(
                  artworks: _favorites.take(8).toList(growable: false),
                  onTap: widget.onArtworkTap,
                  onFavorite: _toggleFavorite,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.total,
    required this.favorites,
    this.onAdd,
  });

  final String name;
  final int total;
  final int favorites;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final nameParts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final firstName = nameParts.isEmpty ? 'there' : nameParts.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    firstName,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$total archived · $favorites favorites',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onAdd != null)
              compact
                  ? IconButton.filled(
                      onPressed: onAdd,
                      tooltip: 'Add a work',
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add a work'),
                    ),
          ],
        );
      },
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.onSelected});

  final ValueChanged<ArtworkCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ArtworkCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = ArtworkCategory.values[index];
          return ActionChip(
            onPressed: () => onSelected(category),
            avatar: Icon(_categoryIcon(category), size: 17),
            label: Text(category.label),
          );
        },
      ),
    );
  }

  IconData _categoryIcon(ArtworkCategory category) => switch (category) {
    ArtworkCategory.book || ArtworkCategory.manga => Icons.menu_book_outlined,
    ArtworkCategory.movie => Icons.local_movies_outlined,
    ArtworkCategory.series || ArtworkCategory.anime => Icons.live_tv_outlined,
    ArtworkCategory.videoGame => Icons.sports_esports_outlined,
    ArtworkCategory.theater => Icons.theater_comedy_outlined,
  };
}

class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({
    required this.artworks,
    required this.onTap,
    required this.onFavorite,
  });

  final List<ArtworkModel> artworks;
  final ValueChanged<ArtworkModel> onTap;
  final ValueChanged<ArtworkModel> onFavorite;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      children: artworks
          .map(
            (artwork) => ArtworkCard(
              title: artwork.title,
              creator: artwork.creator ?? 'Unknown creator',
              category: artwork.category.label,
              imageSource: artwork.imageUrl,
              rating: artwork.rating,
              isFavorite: artwork.isFavorite,
              status: artwork.status.label,
              onTap: () => onTap(artwork),
              onFavorite: () => onFavorite(artwork),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
