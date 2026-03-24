import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../config/app_constants.dart';

class CreatePostDialog extends StatefulWidget {
  final void Function(PostCard) onPostCreated;
  final int selectedChannelIndex;

  const CreatePostDialog({
    super.key,
    required this.onPostCreated,
    required this.selectedChannelIndex,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  String? selectedGifUrl;
  String? selectedImageUrl;
  int gifImageIndex = 0;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a Post'),
      backgroundColor: AppColors.background,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title/Content
            TextField(
              controller: titleController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryText,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryText,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.accentBlurple,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: descriptionController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Add description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryText,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryText,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.accentBlurple,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            // GIF/Image Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Media (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedGifUrl = AppConstants.mockGifUrls[gifImageIndex % 3];
                              selectedImageUrl = null;
                              gifImageIndex++;
                            });
                          },
                          icon: const Icon(Icons.gif),
                          label: const Text('Add GIF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedImageUrl = AppConstants.mockImageUrls[gifImageIndex % 3];
                              selectedGifUrl = null;
                              gifImageIndex++;
                            });
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Add Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Preview
            if (selectedGifUrl != null || selectedImageUrl != null)
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    selectedGifUrl ?? selectedImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppColors.lightGrey400,
                        ),
                      );
                    },
                  ),
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
        ElevatedButton(
          onPressed: () {
            final postContent = titleController.text.trim();
            if (postContent.isNotEmpty) {
              final newPost = PostCard(
                id: DateTime.now().toString(),
                author: 'You',
                authorInitial: 'Y',
                timestamp: 'just now',
                content: postContent,
                description: descriptionController.text.trim(),
                avatarColor: Colors.blueAccent,
                likes: 0,
                channelIndex: widget.selectedChannelIndex,
                gifUrl: selectedGifUrl,
                imageUrl: selectedImageUrl,
              );
              Navigator.pop(context);
              widget.onPostCreated(newPost);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlurple,
          ),
          child: const Text('Post'),
        ),
      ],
    );
  }
}
