import 'package:flutter/material.dart';

import '../models/artwork_model.dart';
import '../services/artwork_service.dart';
import '../widgets/artwork_form.dart';
import '../widgets/editorial_page.dart';

class EditArtworkPage extends StatelessWidget {
  const EditArtworkPage({
    super.key,
    required this.artworkService,
    required this.artwork,
    required this.onSaved,
    this.onCancel,
  });

  final ArtworkService artworkService;
  final ArtworkModel artwork;
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
        title: const Text('Edit work'),
      ),
      body: EditorialPage(
        maxWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refine your record',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Update the details, status, or rating for ${artwork.title}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            ArtworkForm(
              userId: artworkService.userId,
              initialArtwork: artwork,
              submitLabel: 'Save Changes',
              onCancel: cancel,
              onSubmit: (updated) async {
                final saved = await artworkService.updateArtwork(updated);
                onSaved(saved);
              },
            ),
          ],
        ),
      ),
    );
  }
}
