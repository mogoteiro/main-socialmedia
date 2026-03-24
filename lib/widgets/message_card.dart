import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessageCard extends StatefulWidget {
  final Message message;
  final bool isCompact;
  final String currentUserId;
  final Function(Message) onReply;
  final Function(String emoji) onReactionAdd;
  final Function(String emoji) onReactionRemove;
  final Function()? onPin;
  final Function() onDelete;
  final Function(Message)? onEdit;
  final VoidCallback onMentionTap;

  const MessageCard({
    super.key,
    required this.message,
    this.isCompact = false,
    required this.currentUserId,
    required this.onReply,
    required this.onReactionAdd,
    required this.onReactionRemove,
    this.onPin,
    required this.onDelete,
    required this.onMentionTap,
    this.onEdit,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  final List<String> _commonEmojis = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🔥',
    '👏',
    '💯',
  ];
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isEdited = widget.message.isEdited;
    final userReaction = _getUserReaction();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF242526), // FB Card Color
          borderRadius: BorderRadius.circular(0), // Feed usually has square corners or slight radius
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Time, Menu
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      widget.message.authorName.isNotEmpty
                          ? widget.message.authorName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.authorName,
                          style: const TextStyle(
                            color: Color(0xFFE4E6EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(widget.message.timestamp),
                              style: const TextStyle(
                                color: Color(0xFFB0B3B8),
                                fontSize: 12,
                              ),
                            ),
                            if (isEdited)
                              const Text(
                                ' • Edited',
                                style: TextStyle(color: Color(0xFFB0B3B8), fontSize: 12),
                              ),
                            if (widget.message.isPinned) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.push_pin, size: 12, color: Color(0xFFB0B3B8)),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Color(0xFFB0B3B8)),
                    onPressed: () => _showMessageActions(context),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3B3C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Replying to ${widget.message.replyTo!.authorName}: ${widget.message.replyTo!.content}',
                        style: const TextStyle(color: Color(0xFFB0B3B8), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  _buildMessageContent(widget.message.content),
                ],
              ),
            ),

            // Image Grid
            _buildImageGrid(context),

            // Stats Row (Reactions Count)
            if (widget.message.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: GestureDetector(
                  onTap: () {
                    // Aggregate all reactions
                    final allUserIds = widget.message.reactions
                        .expand((r) => r.userIds)
                        .toSet()
                        .toList();
                    _showReactors(context, 'Reactions', allUserIds);
                  },
                  child: _buildReactionSummary(),
                ),
              ),

            // Divider
            const Divider(height: 1, color: Color(0xFF3E4042)),

            // Action Buttons (Like, Comment, Share)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: _buildFeedActionButton(
                    iconWidget: userReaction != null 
                        ? Text(userReaction.emoji, style: const TextStyle(fontSize: 20))
                        : const Icon(Icons.thumb_up_outlined, color: Color(0xFFB0B3B8), size: 20),
                    label: userReaction != null ? userReaction.emoji : 'Like',
                    color: userReaction != null ? Colors.blue : const Color(0xFFB0B3B8),
                    onTap: () {
                       if (userReaction != null) {
                         widget.onReactionRemove(userReaction.emoji);
                       } else {
                         widget.onReactionAdd('👍');
                       }
                    },
                    onLongPress: () => _showReactionPicker(context),
                  )),
                  Expanded(child: _buildFeedActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: 'Comment',
                    onTap: () => widget.onReply(widget.message),
                  )),
                  Expanded(child: _buildFeedActionButton(
                    icon: Icons.push_pin_outlined, // Using Pin as Share placeholder
                    label: 'Pin',
                    onTap: widget.onPin ?? () {},
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = widget.message.attachments.isNotEmpty
        ? widget.message.attachments
        : (widget.message.imageUrl != null && widget.message.imageUrl!.isNotEmpty
            ? [widget.message.imageUrl!]
            : <String>[]);

    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (images.length == 1) {
            return _buildSingleImage(images[0]);
          } else if (images.length == 2) {
            return Row(
              children: [
                Expanded(child: _buildSingleImage(images[0], height: 250)),
                const SizedBox(width: 4),
                Expanded(child: _buildSingleImage(images[1], height: 250)),
              ],
            );
          } else {
            return Column(
              children: [
                _buildSingleImage(images[0], height: 250),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _buildSingleImage(images[1], height: 150)),
                    const SizedBox(width: 4),
                    Expanded(child: _buildSingleImage(images[2], height: 150)),
                    if (images.length > 3) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 150,
                          color: Colors.grey[800],
                          alignment: Alignment.center,
                          child: Text(
                            '+${images.length - 3}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSingleImage(String url, {double? height}) {
    return Image.network(url, height: height, width: double.infinity, fit: BoxFit.cover);
  }

  Widget _buildReactionSummary() {
    // Sort reactions by count
    final sortedReactions = List<MessageReaction>.from(widget.message.reactions)
      ..sort((a, b) => b.userIds.length.compareTo(a.userIds.length));

    return Row(
      children: [
        ...sortedReactions.take(3).map((r) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(r.emoji, style: const TextStyle(fontSize: 16)),
        )),
        const SizedBox(width: 4),
        Text(
          _getReactionSummary(),
          style: const TextStyle(color: Color(0xFFB0B3B8), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFeedActionButton({
    IconData? icon,
    Widget? iconWidget, 
    required String label, 
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color color = const Color(0xFFB0B3B8)
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ?? Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MessageReaction? _getUserReaction() {
    for (var r in widget.message.reactions) {
      if (r.userIds.contains(widget.currentUserId)) {
        return r;
      }
    }
    return null;
  }

  String _getReactionSummary() {
    int count = 0;
    for (var r in widget.message.reactions) {
      count += r.userIds.length;
    }
    if (count == 0) return '';
    return '$count';
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF242526),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        height: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('React to post', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _commonEmojis.map((emoji) => GestureDetector(
                  onTap: () {
                    widget.onReactionAdd(emoji);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF3A3B3C),
                    ),
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF242526),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Post Options',
                style: TextStyle(
                  color: Color(0xFFE4E6EB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFE4E6EB)),
                title: const Text(
                  'Reply to Post',
                  style: TextStyle(color: Color(0xFFE4E6EB)),
                ),
                onTap: () {
                  widget.onReply(widget.message);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin, color: Color(0xFFE4E6EB)),
                title: const Text(
                  'Pin Post',
                  style: TextStyle(color: Color(0xFFE4E6EB)),
                ),
                onTap: widget.onPin != null ? () {
                  widget.onPin!();
                  Navigator.pop(context);
                } : null,
              ),
              if (widget.message.authorId == widget.currentUserId) ...[
                const Divider(color: Color(0xFF3E4042)),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFFE4E6EB)),
                  title: const Text(
                    'Edit Post',
                    style: TextStyle(color: Color(0xFFE4E6EB)),
                  ),
                  onTap: () {
                    if(widget.onEdit != null) widget.onEdit!(widget.message);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Move to Trash',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(String content) {
    // Parse mentions (@username)
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);

    if (matches.isEmpty) {
      return Text(content, style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 15));
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: content.substring(lastEnd, match.start),
            style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 15),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(0)!,
          style: const TextStyle(
            color: Color(0xFFC9CDFB), // Discord Mention Blue
            backgroundColor: Color(0x4D5865F2), // Blurple with opacity
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastEnd),
          style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 15),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  void _showReactors(BuildContext context, String emoji, List<String> userIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF313338),
        title: Text('$emoji Reactions (${userIds.length})', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<String>>(
            future: _fetchUserNames(userIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              final names = snapshot.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: names.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.white70),
                  title: Text(names[index], style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _fetchUserNames(List<String> userIds) async {
    final names = <String>[];
    for (final uid in userIds) {
      if (uid == widget.currentUserId) {
        names.add('You');
        continue;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      names.add(data?['username'] ?? data?['displayName'] ?? 'Unknown User');
    }
    return names;
  }
}
