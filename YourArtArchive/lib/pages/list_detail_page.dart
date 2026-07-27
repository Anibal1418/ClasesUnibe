import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/list_model.dart';
import '../services/artwork_service.dart';
import '../services/list_service.dart';
import '../widgets/feature_ui_components.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({
    super.key,
    required this.userId,
    required this.listId,
    this.listService,
    this.artworkService,
    this.onArtworkTap,
    this.onChanged,
  });

  final int userId;
  final int listId;
  final ListService? listService;
  final ArtworkService? artworkService;
  final ValueChanged<int>? onArtworkTap;
  final VoidCallback? onChanged;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  late ListService _listService;
  late ArtworkService _artworkService;
  ListModel? _list;
  List<ArtworkModel> _artworks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveServices();
    _load();
  }

  @override
  void didUpdateWidget(covariant ListDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId ||
        oldWidget.userId != widget.userId ||
        oldWidget.listService != widget.listService ||
        oldWidget.artworkService != widget.artworkService) {
      _resolveServices();
      _load();
    }
  }

  void _resolveServices() {
    _listService = widget.listService ?? ListService(userId: widget.userId);
    _artworkService =
        widget.artworkService ?? ArtworkService(userId: widget.userId);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _listService.getListById(widget.listId);
      final artworks = await _listService.getArtworksInList(widget.listId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _artworks = artworks;
        _loading = false;
        _error = list == null ? 'This list no longer exists.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This list could not be loaded.';
      });
    }
  }

  Future<void> _addArtwork() async {
    try {
      final all = await _artworkService.getAllArtworks();
      final includedIds = _artworks.map((work) => work.id).toSet();
      final available = all
          .where((work) => work.id != null && !includedIds.contains(work.id))
          .toList(growable: false);
      if (!mounted) return;
      if (available.isEmpty) {
        showFeatureMessage(
          context,
          all.isEmpty
              ? 'Add a work to your archive first.'
              : 'Every work in your archive is already on this list.',
        );
        return;
      }
      final artworkId = await showDialog<int>(
        context: context,
        builder: (_) => _ArtworkPickerDialog(artworks: available),
      );
      if (artworkId == null) return;
      await _listService.addArtworkToList(
        listId: widget.listId,
        artworkId: artworkId,
      );
      if (!mounted) return;
      showFeatureMessage(context, 'Work added to list.');
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(context, 'We could not add that work.', error: true);
    }
  }

  Future<void> _remove(ArtworkModel artwork) async {
    if (artwork.id == null) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from list?'),
            content: Text(
              '“${artwork.title}” will remain safely in your archive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _listService.removeArtworkFromList(
        listId: widget.listId,
        artworkId: artwork.id!,
      );
      if (!mounted) return;
      showFeatureMessage(context, 'Work removed from list.');
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(
        context,
        'We could not remove that work.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      backgroundColor: featureCream,
      appBar: AppBar(
        title: Text(list?.title ?? 'List'),
        actions: [
          if (list != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _addArtwork,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add work'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? FeatureAsyncError(message: _error!, onRetry: _load)
            : RefreshIndicator(onRefresh: _load, child: _buildContent(list!)),
      ),
    );
  }

  Widget _buildContent(ListModel list) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: FeaturePageBody(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
              24,
              MediaQuery.sizeOf(context).width >= 840 ? 32 : 20,
              20,
            ),
            child: FeaturePanel(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runAlignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 14,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          list.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: featureBrown,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if ((list.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            list.description!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: featureMuted, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FeaturePill(
                        label: list.isPublic ? 'Public' : 'Private',
                        icon: list.isPublic
                            ? Icons.public_rounded
                            : Icons.lock_outline_rounded,
                        color: list.isPublic ? featureGreen : featureMuted,
                      ),
                      FeaturePill(
                        label:
                            '${_artworks.length} ${_artworks.length == 1 ? 'work' : 'works'}',
                        icon: Icons.auto_stories_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_artworks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: FeatureEmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'This list has room to grow',
              message:
                  'Choose a work from your archive to begin this collection.',
              actionLabel: 'Add work',
              onAction: _addArtwork,
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
                final columns = available >= 980
                    ? 4
                    : available >= 700
                    ? 3
                    : available >= 380
                    ? 2
                    : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 350,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final artwork = _artworks[index];
                    return _ListArtworkCard(
                      artwork: artwork,
                      onTap: widget.onArtworkTap == null || artwork.id == null
                          ? null
                          : () => widget.onArtworkTap!(artwork.id!),
                      onRemove: () => _remove(artwork),
                    );
                  }, childCount: _artworks.length),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ListArtworkCard extends StatelessWidget {
  const _ListArtworkCard({
    required this.artwork,
    required this.onTap,
    required this.onRemove,
  });

  final ArtworkModel artwork;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              FeatureNetworkArtworkImage(
                imageUrl: artwork.imageUrl,
                title: artwork.title,
                height: 215,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: .94),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Remove from list',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, color: featureBrown),
                  ),
                ),
              ),
              if (artwork.rating != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FeatureRatingBadge(
                    rating: artwork.rating!,
                    compact: true,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: featureBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (artwork.creator ?? '').trim().isEmpty
                        ? artwork.category.label
                        : artwork.creator!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: featureMuted),
                  ),
                  const Spacer(),
                  FeaturePill(
                    label: artwork.category.label,
                    icon: Icons.local_offer_outlined,
                    color: featureGold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkPickerDialog extends StatefulWidget {
  const _ArtworkPickerDialog({required this.artworks});

  final List<ArtworkModel> artworks;

  @override
  State<_ArtworkPickerDialog> createState() => _ArtworkPickerDialogState();
}

class _ArtworkPickerDialogState extends State<_ArtworkPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.artworks
        .where((artwork) {
          return query.isEmpty ||
              artwork.title.toLowerCase().contains(query) ||
              (artwork.creator ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Add a work'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search your archive',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No works match this search.'))
                  : ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final artwork = matches[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FeatureNetworkArtworkImage(
                              imageUrl: artwork.imageUrl,
                              title: artwork.title,
                              width: 48,
                              height: 58,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          title: Text(artwork.title),
                          subtitle: Text(artwork.category.label),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                          ),
                          onTap: () => Navigator.pop(context, artwork.id),
                        );
                      },
                    ),
            ),
          ],
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
