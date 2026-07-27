import 'package:flutter/material.dart';

import '../models/list_model.dart';
import '../services/artwork_service.dart';
import '../services/list_service.dart';
import '../widgets/feature_ui_components.dart';
import 'list_detail_page.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({
    super.key,
    required this.userId,
    this.listService,
    this.artworkService,
    this.onListTap,
    this.onChanged,
  });

  final int userId;
  final ListService? listService;
  final ArtworkService? artworkService;
  final ValueChanged<ListModel>? onListTap;
  final VoidCallback? onChanged;

  @override
  State<ListsPage> createState() => ListsPageState();
}

class ListsPageState extends State<ListsPage> {
  late ListService _listService;
  late ArtworkService _artworkService;
  List<ListModel> _lists = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveServices();
    _load();
  }

  @override
  void didUpdateWidget(covariant ListsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
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

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final lists = await _listService.getAllLists();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your lists could not be loaded.';
      });
    }
  }

  Future<void> _createOrEdit([ListModel? existing]) async {
    final draft = await showDialog<_ListDraft>(
      context: context,
      builder: (_) => _ListEditorDialog(existing: existing),
    );
    if (draft == null) return;
    try {
      if (existing == null) {
        await _listService.createList(
          ListModel(
            userId: widget.userId,
            title: draft.title,
            description: draft.description,
            isPublic: draft.isPublic,
          ),
        );
      } else {
        await _listService.updateList(
          existing.copyWith(
            title: draft.title,
            description: draft.description,
            isPublic: draft.isPublic,
          ),
        );
      }
      if (!mounted) return;
      showFeatureMessage(
        context,
        existing == null ? 'List created.' : 'List updated.',
      );
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(context, 'We could not save that list.', error: true);
    }
  }

  Future<void> _delete(ListModel list) async {
    if (list.id == null) return;
    final confirmed = await showFeatureDeleteConfirmation(
      context,
      title: 'Delete “${list.title}”?',
      message:
          'The list will be removed, but every work will remain in your archive.',
    );
    if (!confirmed) return;
    try {
      await _listService.deleteList(list.id!);
      if (!mounted) return;
      showFeatureMessage(context, 'List deleted.');
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) return;
      showFeatureMessage(
        context,
        'We could not delete that list.',
        error: true,
      );
    }
  }

  Future<void> _open(ListModel list) async {
    if (widget.onListTap != null) {
      widget.onListTap!(list);
      return;
    }
    if (list.id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ListDetailPage(
          userId: widget.userId,
          listId: list.id!,
          listService: _listService,
          artworkService: _artworkService,
        ),
      ),
    );
    await _load();
    if (changed == true) {
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: featureCream,
      appBar: AppBar(
        title: const Text('My Lists'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _createOrEdit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create list'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: FeatureAsyncError(message: _error!, onRetry: _load),
          ),
        ],
      );
    }
    if (_lists.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: FeatureEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Create a shelf with a point of view',
              message:
                  'Group works around a mood, a theme, a trip, or anything you want to revisit.',
              actionLabel: 'Create list',
              onAction: () => _createOrEdit(),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 840 ? 32.0 : 20.0;
        final available = (constraints.maxWidth - horizontal * 2)
            .clamp(0, 1120)
            .toDouble();
        final columns = available >= 940
            ? 3
            : available >= 600
            ? 2
            : 1;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            mainAxisExtent: 235,
          ),
          itemCount: _lists.length,
          itemBuilder: (context, index) {
            final list = _lists[index];
            return _ListCard(
              list: list,
              onTap: () => _open(list),
              onEdit: () => _createOrEdit(list),
              onDelete: () => _delete(list),
            );
          },
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ListModel list;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8E4C25), featureBrown],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  color: featureCream.withValues(alpha: .9),
                  size: 30,
                ),
                const Spacer(),
                PopupMenuButton<_ListAction>(
                  tooltip: 'List actions',
                  iconColor: Colors.white,
                  onSelected: (action) {
                    switch (action) {
                      case _ListAction.edit:
                        onEdit();
                      case _ListAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ListAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ListAction.delete,
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
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: featureBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      (list.description ?? '').trim().isEmpty
                          ? 'A personal collection from your archive.'
                          : list.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: featureMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      FeaturePill(
                        label: list.isPublic ? 'Public' : 'Private',
                        icon: list.isPublic
                            ? Icons.public_rounded
                            : Icons.lock_outline_rounded,
                        color: list.isPublic ? featureGreen : featureMuted,
                      ),
                      const Spacer(),
                      Text(
                        '${list.artworkCount} ${list.artworkCount == 1 ? 'work' : 'works'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: featureMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: featureGold,
                        size: 18,
                      ),
                    ],
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

class _ListEditorDialog extends StatefulWidget {
  const _ListEditorDialog({this.existing});

  final ListModel? existing;

  @override
  State<_ListEditorDialog> createState() => _ListEditorDialogState();
}

class _ListEditorDialogState extends State<_ListEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _isPublic = widget.existing?.isPublic ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ListDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create a list' : 'Edit list'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'List title',
                    hintText: 'Books that changed me',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title for your list.'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  title: const Text('Public list'),
                  subtitle: Text(
                    _isPublic
                        ? 'This collection may be shared.'
                        : 'Only you can see this collection.',
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Create list' : 'Save changes'),
        ),
      ],
    );
  }
}

class _ListDraft {
  const _ListDraft({
    required this.title,
    required this.description,
    required this.isPublic,
  });

  final String title;
  final String description;
  final bool isPublic;
}

enum _ListAction { edit, delete }
