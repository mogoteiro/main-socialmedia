// Import: dart:io - Para sa file handling (e.g., image attachments sa mobile)
// Import: flutter/material.dart - Pangunahing Flutter UI widgets
// Import: flutter/foundation.dart - Para sa kIsWeb check (web vs mobile differences)
// Import: image_picker - Para sa pagpili ng images mula gallery/camera
// Import: firebase_auth - Para makuha current user info (uid, name)
// Import: models/message_model.dart - Data model para sa messages
// Import: services/message_service.dart - Business logic para send/edit/delete messages, streams
// Import: widgets/message_card.dart - UI component para i-display ang bawat message
// Import: screens/thread_screen.dart - Screen para sa thread/replies ng specific message
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../widgets/message_card.dart';
import 'thread_screen.dart';
import 'voice_chat_screen.dart';

// Widget: ChannelScreen
// Gamit: Pangunahing chat screen ng isang channel. Nagpapakita ng messages list,
// typing indicator, image upload, reply/edit/delete/pin/reactions.
// Connected sa: message_service.dart (streams, send ops), message_card.dart (display),
// thread_screen.dart (replies), firebase_auth (current user).
class ChannelScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final TextEditingController _messageController = TextEditingController();
  final MessageService _messageService = MessageService.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late FocusNode _messageFocus;
  Message? _replyingTo;
  Message? _editingMessage;
  bool _isSending = false;
  bool _isTyping = false;
  XFile? _attachmentFile;
  final ImagePicker _picker = ImagePicker();

// Lifecycle: initState
// Gamit: I-set up ang focus node at listener para real-time typing detection.
// Connected sa: _onMessageChanged na nag-u-update ng Firestore typing status.
  @override
  void initState() {
    super.initState();
    _messageFocus = FocusNode();
    _messageController.addListener(_onMessageChanged);
  }

// Function: _onMessageChanged
// Gamit: Nakikinig sa changes sa message input. Nag-update ng typing indicator sa UI at Firestore.
// Connected sa: message_service.setTypingStatus para real-time sync sa ibang users.
  void _onMessageChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      setState(() => _isTyping = isCurrentlyTyping);
      _messageService.setTypingStatus(
        widget.channelId,
        _currentUser?.uid ?? '',
        _currentUser?.displayName ?? 'Unknown',
        isCurrentlyTyping,
      );
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages.')),
      );
      return;
    }

    if (content.isEmpty && _attachmentFile == null) {
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_editingMessage != null) {
        await _messageService.editMessage(widget.channelId, _editingMessage!.id, content);
        setState(() {
          _editingMessage = null;
        });
      } else {
        String? imageUrl;
        if (_attachmentFile != null) {
          final bytes = await _attachmentFile!.readAsBytes();
          // Always upload bytes to handle Android scoped storage and Web consistently
          imageUrl = await _messageService.uploadImageBytesToStorage(widget.channelId, bytes);
        }

        await _messageService.sendMessageWithReply(
          widget.channelId,
          _currentUser.uid,
          _currentUser.displayName ?? 'Unknown',
          content,
          imageUrl: imageUrl,
          replyToMessageId: _replyingTo?.id,
          replyToAuthorName: _replyingTo?.authorName,
          replyToContent: _replyingTo?.content,
        );
      }

      _messageController.clear();
      setState(() {
        _attachmentFile = null;
        _replyingTo = null;
        _isTyping = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully! ✓'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _attachmentFile = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18191A), // FB Feed Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF242526), // FB Header
        title: Text('# ${widget.channelName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFFB5BAC1),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic, color: Color(0xFFB5BAC1)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoiceChatScreen(
                  channelId: widget.channelId,
                  channelName: widget.channelName,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.push_pin, color: Color(0xFFB5BAC1)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => PinnedMessagesDialog(
                  channelId: widget.channelId,
                  messageService: _messageService,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messageService.getMessagesStream(widget.channelId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                // Filter out replies so they only appear in ThreadScreen
                final messages = (snapshot.data ?? []).where((m) => m.replyTo == null).toList();

                return Column(
                  children: [
                    // Typing indicator
                    StreamBuilder<List<String>>(
                      stream: _messageService.getTypingUsersStream(widget.channelId),
                      builder: (context, typingSnapshot) {
                        final typingUsers =
                            (typingSnapshot.data ?? [])
                                .where((u) => u != (_currentUser?.displayName ?? ''))
                                .toList();
                        if (typingUsers.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${typingUsers.join(', ')} ${typingUsers.length > 1 ? 'are' : 'is'} typing...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Start the conversation!',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];

                                return MessageCard(
                                  message: message,
                                  isCompact: false, // Newsfeed always shows full card
                                  currentUserId: _currentUser?.uid ?? '',
                                  onReply: (msg) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ThreadScreen(
                                            parentMessage: msg, channelId: widget.channelId),
                                      ),
                                    );
                                  },
                                  onEdit: (msg) {
                                    setState(() {
                                      _editingMessage = msg;
                                      _messageController.text = msg.content;
                                      _replyingTo = null; // Cancel reply if editing
                                    });
                                    _messageFocus.requestFocus();
                                  },
                                  onReactionAdd: (emoji) {
                                    _messageService.addReaction(
                                      widget.channelId,
                                      message.id,
                                      emoji,
                                      _currentUser?.uid ?? '',
                                    );
                                  },
                                  onReactionRemove: (emoji) {
                                    _messageService.removeReaction(
                                      widget.channelId,
                                      message.id,
                                      emoji,
                                      _currentUser?.uid ?? '',
                                    );
                                  },
                                  onPin: () {
                                    _messageService.pinMessage(
                                      widget.channelId,
                                      message.id,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Message pinned')),
                                      );
                                    }
                                  },
                                  onDelete: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Message'),
                                        content: const Text('Are you sure?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _messageService.deleteMessage(
                                                widget.channelId,
                                                message.id,
                                              );
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onMentionTap: () {
                                    _messageController.text =
                                        '${_messageController.text}@${message.authorName} ';
                                    _messageController.selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _messageController.text.length,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_replyingTo != null || _editingMessage != null || _attachmentFile != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF242526),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingTo != null || _editingMessage != null)
                        Text(
                          _editingMessage != null ? 'Editing Message:' : 'Replying to:',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB5BAC1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        if (_replyingTo != null)
                        Text(
                          _replyingTo!.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5BAC1),
                          ),
                        ),
                        if (_replyingTo != null)
                        Text(
                          _replyingTo!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        
                        if (_attachmentFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                              child: kIsWeb
                                  ? Image.network(_attachmentFile!.path, fit: BoxFit.cover)
                                  : Image.file(File(_attachmentFile!.path), fit: BoxFit.cover),
                            ),
                          ),
                        ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _replyingTo = null;
                      _editingMessage = null;
                      _attachmentFile = null;
                      _messageController.clear();
                    }),
                  ),
                ],
              ),
            ),
            
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF242526),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFFB5BAC1)),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3B3C), // FB Input
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      focusNode: _messageFocus,
                      controller: _messageController,
                      style: const TextStyle(color: Color(0xFFDBDEE1)),
                      decoration: InputDecoration(
                        hintText: 'Message #${widget.channelName}',
                        hintStyle: const TextStyle(color: Color(0xFF949BA4)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                      enabled: !_isSending,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_isTyping) {
      _messageService.setTypingStatus(
        widget.channelId,
        _currentUser?.uid ?? '',
        _currentUser?.displayName ?? 'Unknown',
        false,
      );
    }
    super.dispose();
  }
}

class PinnedMessagesDialog extends StatelessWidget {
  final String channelId;
  final MessageService messageService;

  const PinnedMessagesDialog({
    super.key,
    required this.channelId,
    required this.messageService,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF242526),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Pinned Messages',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: messageService.getPinnedMessagesStream(channelId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      'Error: ${snapshot.error}\n\nYou may need to create an index in Firestore.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final pinnedMessages = snapshot.data ?? [];
                if (pinnedMessages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No pinned messages',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pinnedMessages.length,
                  itemBuilder: (context, index) {
                    final message = pinnedMessages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3B3C),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(color: Colors.amber, width: 3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.authorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.content,
                                    style: const TextStyle(color: Color(0xFFDBDEE1)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              tooltip: 'Unpin message',
                              onPressed: () => messageService.unpinMessage(channelId, message.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}