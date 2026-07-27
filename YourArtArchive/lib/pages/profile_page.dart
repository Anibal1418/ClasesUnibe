import 'package:flutter/material.dart';

import '../models/list_model.dart';
import '../models/user_model.dart';
import '../services/artwork_service.dart';
import '../services/list_service.dart';
import '../widgets/feature_ui_components.dart';
import 'lists_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.onLogout,
    this.artworkService,
    this.listService,
    this.onOpenLists,
  });

  final UserModel user;
  final VoidCallback onLogout;
  final ArtworkService? artworkService;
  final ListService? listService;
  final VoidCallback? onOpenLists;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late ArtworkService _artworkService;
  late ListService _listService;
  ProfileStats? _stats;
  bool _loading = true;
  String? _error;

  int get _userId => widget.user.id!;

  @override
  void initState() {
    super.initState();
    _resolveServices();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.artworkService != widget.artworkService ||
        oldWidget.listService != widget.listService) {
      _resolveServices();
      _loadStats();
    }
  }

  void _resolveServices() {
    _artworkService = widget.artworkService ?? ArtworkService(userId: _userId);
    _listService = widget.listService ?? ListService(userId: _userId);
  }

  Future<void> refresh() => _loadStats();

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stats = await _artworkService.getProfileStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your profile statistics could not be loaded.';
      });
    }
  }

  Future<void> _openLists() async {
    if (widget.onOpenLists != null) {
      widget.onOpenLists!();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListsPage(
          userId: _userId,
          listService: _listService,
          artworkService: _artworkService,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.logout_rounded, color: featureGold),
            title: const Text('Log out?'),
            content: const Text(
              'Your archive will stay on this device. You can log back in at any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: featureCream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FeaturePageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHero(user: widget.user),
                      const SizedBox(height: 24),
                      if (_loading)
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        FeatureAsyncError(message: _error!, onRetry: _loadStats)
                      else
                        _StatsGrid(stats: _stats!),
                      const SizedBox(height: 24),
                      FeaturePanel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: const _FeatureIconTile(
                                icon: Icons.collections_bookmark_outlined,
                              ),
                              title: const Text('My Lists'),
                              subtitle: const Text(
                                'Curate and revisit your collections',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _openLists,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: const _FeatureIconTile(
                                icon: Icons.info_outline_rounded,
                              ),
                              title: const Text('About YourArtArchive'),
                              subtitle: const Text(
                                'Your personal cultural memory',
                              ),
                              trailing: const Text(
                                '1.0',
                                style: TextStyle(color: featureMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: featureRust,
                          side: BorderSide(
                            color: featureRust.withValues(alpha: .35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Member since ${widget.user.createdAt.toLocal().year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: featureMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width >= 600 ? 32 : 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F4825), featureBrown],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final avatar = Semantics(
            label: '${user.name} avatar',
            child: CircleAvatar(
              radius: compact ? 40 : 48,
              backgroundColor: featureCream,
              child: Text(
                initial,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: featureBrown,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          final details = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: featureCream,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                user.email,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: featureCream.withValues(alpha: .75),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Building a personal archive, one story at a time.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: featureCream.withValues(alpha: .88),
                  height: 1.45,
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              children: [avatar, const SizedBox(height: 18), details],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        label: 'Archived',
        value: stats.totalWorks,
        icon: Icons.archive_outlined,
      ),
      (
        label: 'Completed',
        value: stats.completed,
        icon: Icons.check_circle_outline_rounded,
      ),
      (
        label: 'Reviews',
        value: stats.reviews,
        icon: Icons.star_outline_rounded,
      ),
      (
        label: 'Favorites',
        value: stats.favorites,
        icon: Icons.favorite_border_rounded,
      ),
      (
        label: 'Lists',
        value: stats.lists,
        icon: Icons.collections_bookmark_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: FeaturePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      Icon(item.icon, color: featureGold, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        '${item.value}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: featureBrown,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: featureMuted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureIconTile extends StatelessWidget {
  const _FeatureIconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: featureGold.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: featureGold),
    );
  }
}
