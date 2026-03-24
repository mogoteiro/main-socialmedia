// Import: flutter/material.dart - UI widgets
// Import: firebase_auth - Current user info
// Import: models/message_model.dart - Message data
// Import: services/message_service.dart - Replies stream, reactions
// Import: widgets/message_card.dart - Message UI
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../widgets/message_card.dart';

// Widget: ThreadScreen
// Gamit: Thread view for replies to a parent message, with reply input.
// Connected sa: channel_screen.dart (launched from onReply), message_service (replies stream).
class ThreadScreen extends StatefulWidget {
  final Message parentMessage;
  final String channelId;

  const ThreadScreen({
    super.key,
    required this.parentMessage,
    required this.channelId,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final TextEditingController _replyController = TextEditingController();
  final MessageService _messageService = MessageService.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isSending = false;

  void _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _currentUser == null) return;

    setState(() => _isSending = true);

    try {
      await _messageService.sendMessageWithReply(
        widget.channelId,
        _currentUser!.uid,
        _currentUser!.displayName ?? 'Unknown',
        content,
        replyToMessageId: widget.parentMessage.id,
        replyToAuthorName: widget.parentMessage.authorName,
        replyToContent: widget.parentMessage.content,
      );
      _replyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18191A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF242526),
        title: const Text('Thread', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Parent Post
                  MessageCard(
                    message: widget.parentMessage,
                    currentUserId: _currentUser?.uid ?? '',
                    onReply: (_) {}, // No-op in thread view header
                    onReactionAdd: (emoji) => _messageService.addReaction(
                        widget.channelId, widget.parentMessage.id, emoji, _currentUser?.uid ?? ''),
                    onReactionRemove: (emoji) => _messageService.removeReaction(
                        widget.channelId, widget.parentMessage.id, emoji, _currentUser?.uid ?? ''),
                    onPin: null,
                    onDelete: () {},
                    onMentionTap: () {},
                  ),
                  const Divider(color: Color(0xFF3E4042), thickness: 1),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Replies', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // Replies Stream
                  StreamBuilder<List<Message>>(
                    stream: _messageService.getRepliesStream(widget.channelId, widget.parentMessage.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
                      }
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final replies = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          return MessageCard(
                            message: replies[index],
                            currentUserId: _currentUser?.uid ?? '',
                            onReply: (_) {},
                            onReactionAdd: (emoji) => _messageService.addReaction(
                                widget.channelId, replies[index].id, emoji, _currentUser?.uid ?? ''),
                            onReactionRemove: (emoji) => _messageService.removeReaction(
                                widget.channelId, replies[index].id, emoji, _currentUser?.uid ?? ''),
                            onPin: null,
                            onDelete: () => _messageService.deleteMessage(widget.channelId, replies[index].id),
                            onMentionTap: () {},
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF242526),
            child: Row(
              children: [
                Expanded(
                  child: TextField(controller: _replyController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Write a reply...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none)),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _isSending ? null : _sendReply),
              ],
            ),
          ),
        ],
      ),
    );
  }
}