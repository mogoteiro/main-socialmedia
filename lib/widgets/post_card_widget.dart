import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../config/app_constants.dart';

class PostCardWidget extends StatefulWidget {
  final PostCard post;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onShare,
    required this.onProfileTap,
  });

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget> {
  final TextEditingController _commentController = TextEditingController();
  bool isLiked = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showMediaFullscreen(BuildContext context, String mediaUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              Center(
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7289DA),
                        ),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[600],
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load media',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Author, Timestamp
            Row(
              children: [
                InkWell(
                  onTap: widget.onProfileTap,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: widget.post.avatarColor,
                    child: Text(
                      widget.post.authorInitial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.author,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.post.timestamp,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGrey400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              widget.post.content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            // Description
            if (widget.post.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.post.description,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.lightGrey400,
                  ),
                ),
              ),
            if (widget.post.description.isNotEmpty)
              const SizedBox(height: 12),
            // GIF or Image
            if (widget.post.gifUrl != null || widget.post.imageUrl != null)
              InkWell(
                onTap: () {
                  // Show fullscreen view
                  _showMediaFullscreen(context, widget.post.gifUrl ?? widget.post.imageUrl!);
                },
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(
                          widget.post.gifUrl ?? widget.post.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentBlurple,
                                ),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      color: AppColors.lightGrey400,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load media',
                                      style: TextStyle(
                                        color: AppColors.lightGrey400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.post.gifUrl != null || widget.post.imageUrl != null)
              const SizedBox(height: 12),
            // Like Count
            Text(
              '${widget.post.likes} likes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.lightGrey400,
              ),
            ),
            Divider(color: AppColors.secondaryText),
            // Action Buttons: Like, Comment, Share
            Row(
              children: [
                Expanded(
                  child: IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : AppColors.lightGrey400,
                    ),
                    onPressed: () {
                      setState(() {
                        isLiked = !isLiked;
                      });
                      widget.onLike();
                    },
                    tooltip: 'Like',
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.lightGrey400,
                    ),
                    onPressed: () {
                      setState(() {});
                    },
                    tooltip: 'Comment',
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: Icon(
                      Icons.share,
                      color: AppColors.lightGrey400,
                    ),
                    onPressed: widget.onShare,
                    tooltip: 'Share',
                  ),
                ),
              ],
            ),
            // Comment Input Field
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(color: AppColors.lightGrey500),
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
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: () {
                      setState(() {
                        _commentController.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comment posted!'),
                          duration: Duration(milliseconds: 800),
                        ),
                      );
                    },
                    color: AppColors.accentBlurple,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
