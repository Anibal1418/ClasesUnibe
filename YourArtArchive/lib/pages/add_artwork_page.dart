import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../services/artwork_service.dart';
import '../widgets/artwork_form.dart';
import '../widgets/editorial_page.dart';

class AddArtworkPage extends StatelessWidget {
  const AddArtworkPage({
    super.key,
    required this.artworkService,
    required this.onSaved,
    this.onCancel,
  });

  final ArtworkService artworkService;
  final ValueChanged<ArtworkModel> onSaved;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    void cancel() {
      if (onCancel != null) {
        onCancel!();
      } else {
        Navigator.maybePop(context);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: cancel,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Add to archive'),
      ),
      body: EditorialPage(
        maxWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new story begins here.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Save the details you care about. You can always edit them later.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            ArtworkForm(
              userId: artworkService.userId,
              submitLabel: 'Add to Archive',
              onCancel: cancel,
              onSubmit: (draft) async {
                final saved = await artworkService.createArtwork(draft);
                onSaved(saved);
              },
            ),
          ],
        ),
      ),
    );
  }
}
