import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../models/user_model.dart';
import '../services/artwork_service.dart';
import '../services/list_service.dart';
import '../services/review_service.dart';
import 'add_artwork_page.dart';
import 'archive_page.dart';
import 'artwork_detail_page.dart';
import 'discover_page.dart';
import 'home_page.dart';
import 'lists_page.dart';
import 'profile_page.dart';
import 'reviews_feed_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user, required this.onLogout});

  final UserModel user;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ArtworkService _artworkService;
  late ReviewService _reviewService;
  late ListService _listService;
  int _selectedIndex = 0;
  int _revision = 0;
  ArtworkCategory? _discoverCategory;

  int get _userId => widget.user.id!;

  @override
  void initState() {
    super.initState();
    _createServices();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _createServices();
      _selectedIndex = 0;
      _revision++;
    }
  }

  void _createServices() {
    _artworkService = ArtworkService(userId: _userId);
    _reviewService = ReviewService(userId: _userId);
    _listService = ListService(userId: _userId);
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() => _revision++);
  }

  void _selectTab(int index, {bool clearDiscoverFilter = false}) {
    setState(() {
      _selectedIndex = index;
      if (index == 1 && clearDiscoverFilter) {
        _discoverCategory = null;
      }
    });
  }

  Future<void> _openAddArtwork() async {
    final saved = await Navigator.of(context).push<ArtworkModel>(
      MaterialPageRoute(
        builder: (routeContext) => AddArtworkPage(
          artworkService: _artworkService,
          onSaved: (artwork) =>
              Navigator.of(routeContext).pop<ArtworkModel>(artwork),
        ),
      ),
    );
    if (saved != null) _refreshData();
  }

  Future<void> _openArtwork(ArtworkModel artwork) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ArtworkDetailPage(
          userId: _userId,
          artworkId: artwork.id!,
          initialArtwork: artwork,
          artworkService: _artworkService,
          reviewService: _reviewService,
          listService: _listService,
          onChanged: _refreshData,
        ),
      ),
    );
    _refreshData();
  }

  Future<void> _openArtworkById(int artworkId) async {
    final artwork = await _artworkService.getArtworkById(artworkId);
    if (!mounted || artwork == null) return;
    await _openArtwork(artwork);
  }

  Future<void> _openLists() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListsPage(
          userId: _userId,
          listService: _listService,
          artworkService: _artworkService,
          onChanged: _refreshData,
        ),
      ),
    );
    _refreshData();
  }

  List<Widget> _pages() => [
    HomePage(
      key: ValueKey('home-$_revision'),
      user: widget.user,
      artworkService: _artworkService,
      onArtworkTap: _openArtwork,
      onDiscover: () => _selectTab(1, clearDiscoverFilter: true),
      onArchive: () => _selectTab(2),
      onAddArtwork: _openAddArtwork,
      onCategorySelected: (category) {
        setState(() {
          _discoverCategory = category;
          _selectedIndex = 1;
        });
      },
    ),
    DiscoverPage(
      key: ValueKey('discover-$_revision-${_discoverCategory?.databaseValue}'),
      artworkService: _artworkService,
      initialCategory: _discoverCategory,
      onArtworkTap: _openArtwork,
      onAddArtwork: _openAddArtwork,
    ),
    ArchivePage(
      key: ValueKey('archive-$_revision'),
      artworkService: _artworkService,
      onArtworkTap: _openArtwork,
      onAddArtwork: _openAddArtwork,
    ),
    ReviewsFeedPage(
      key: ValueKey('reviews-$_revision'),
      userId: _userId,
      reviewService: _reviewService,
      onArtworkTap: _openArtworkById,
      onChanged: _refreshData,
    ),
    ProfilePage(
      key: ValueKey('profile-$_revision'),
      user: widget.user,
      artworkService: _artworkService,
      listService: _listService,
      onOpenLists: _openLists,
      onLogout: widget.onLogout,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final body = IndexedStack(index: _selectedIndex, children: pages);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          final extended = constraints.maxWidth >= 1080;
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: extended,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) =>
                        _selectTab(index, clearDiscoverFilter: index == 1),
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 18),
                      child: extended
                          ? const _BrandLockup()
                          : const Icon(Icons.inventory_2_outlined, size: 28),
                    ),
                    destinations: _destinations
                        .map(
                          (destination) => NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                _selectTab(index, clearDiscoverFilter: index == 1),
            destinations: _destinations
                .map(
                  (destination) => NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 28),
          const SizedBox(width: 10),
          Text('YourArtArchive', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _AppDestination('Home', Icons.home_outlined, Icons.home_rounded),
  _AppDestination('Discover', Icons.explore_outlined, Icons.explore_rounded),
  _AppDestination(
    'Archive',
    Icons.bookmark_border_rounded,
    Icons.bookmark_rounded,
  ),
  _AppDestination('Reviews', Icons.star_border_rounded, Icons.star_rounded),
  _AppDestination(
    'Profile',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  ),
];
