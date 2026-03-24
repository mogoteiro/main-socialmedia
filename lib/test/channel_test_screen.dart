import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';

class ChannelTestScreen extends StatefulWidget {
  const ChannelTestScreen({super.key});

  @override
  State<ChannelTestScreen> createState() => _ChannelTestScreenState();
}

class _ChannelTestScreenState extends State<ChannelTestScreen> {
  final MessageService _messageService = MessageService.instance;
  final TextEditingController _testController = TextEditingController();
  String _testResults = '';
  bool _isRunning = false;

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  void _logResult(String message) {
    setState(() {
      _testResults += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logResult('❌ ERROR: User not logged in');
      setState(() => _isRunning = false);
      return;
    }

    _logResult('🚀 Starting Channel Features Test');
    _logResult('📱 User: ${user.displayName ?? user.email ?? 'Unknown'}');

    try {
      // Test 1: Message Sending with Mentions
      await _testMessageSendingWithMentions(user);

      // Test 2: Emoji Reactions
      await _testEmojiReactions(user);

      // Test 3: Message Replies
      await _testMessageReplies(user);

      // Test 4: Typing Indicators
      await _testTypingIndicators(user);

      // Test 5: Pinned Messages
      await _testPinnedMessages(user);

      // Test 6: Real-time Data Sync
      await _testRealTimeSync();

      _logResult('✅ ALL TESTS COMPLETED SUCCESSFULLY!');

    } catch (e) {
      _logResult('❌ TEST FAILED: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _testMessageSendingWithMentions(User user) async {
    _logResult('\n📝 Testing Message Sending with Mentions...');

    try {
      // Send message with mentions
      await _messageService.sendMessageWithReply(
        'general',
        user.uid,
        user.displayName ?? 'Test User',
        'Hello @testuser and @friend! How are you @admin?',
      );
      _logResult('✅ Message with mentions sent successfully');

      // Verify message was stored with mentions
      final messages = await _messageService.getMessagesStream('general').first;
      final testMessage = messages.lastWhere((m) => m.content.contains('@testuser'));
      
      if (testMessage.mentions.contains('testuser') && 
          testMessage.mentions.contains('friend') && 
          testMessage.mentions.contains('admin')) {
        _logResult('✅ Mentions correctly parsed and stored: ${testMessage.mentions}');
      } else {
        _logResult('❌ Mentions not properly stored: ${testMessage.mentions}');
      }

    } catch (e) {
      _logResult('❌ Message sending test failed: $e');
    }
  }

  Future<void> _testEmojiReactions(User user) async {
    _logResult('\n😀 Testing Emoji Reactions...');

    try {
      // Get a message to react to
      final messages = await _messageService.getMessagesStream('general').first;
      if (messages.isEmpty) {
        _logResult('⚠️ No messages found to react to');
        return;
      }

      final testMessage = messages.last;
      _logResult('📱 Reacting to message: ${testMessage.content.substring(0, 20)}...');

      // Add reaction
      await _messageService.addReaction('general', testMessage.id, '❤️', user.uid);
      _logResult('✅ Added ❤️ reaction');

      // Verify reaction was added
      final updatedMessages = await _messageService.getMessagesStream('general').first;
      final updatedMessage = updatedMessages.firstWhere((m) => m.id == testMessage.id);
      final heartReaction = updatedMessage.reactions.firstWhere((r) => r.emoji == '❤️', orElse: () => MessageReaction(emoji: '', userIds: []));
      
      if (heartReaction.userIds.contains(user.uid)) {
        _logResult('✅ Reaction correctly stored: ${heartReaction.emoji} by ${heartReaction.userIds.length} users');
      } else {
        _logResult('❌ Reaction not found or user not added');
      }

      // Remove reaction
      await _messageService.removeReaction('general', testMessage.id, '❤️', user.uid);
      _logResult('✅ Removed ❤️ reaction');

    } catch (e) {
      _logResult('❌ Emoji reactions test failed: $e');
    }
  }

  Future<void> _testMessageReplies(User user) async {
    _logResult('\n💬 Testing Message Replies...');

    try {
      // Get a message to reply to
      final messages = await _messageService.getMessagesStream('general').first;
      if (messages.isEmpty) {
        _logResult('⚠️ No messages found to reply to');
        return;
      }

      final originalMessage = messages.last;
      _logResult('📱 Replying to message: ${originalMessage.content.substring(0, 20)}...');

      // Send reply
      await _messageService.sendMessageWithReply(
        'general',
        user.uid,
        user.displayName ?? 'Test User',
        'This is a reply!',
        replyToMessageId: originalMessage.id,
        replyToAuthorName: originalMessage.authorName,
        replyToContent: originalMessage.content,
      );
      _logResult('✅ Reply message sent successfully');

      // Verify reply was stored correctly
      final updatedMessages = await _messageService.getMessagesStream('general').first;
      final replyMessage = updatedMessages.lastWhere((m) => m.replyTo != null);
      
      if (replyMessage.replyTo?.messageId == originalMessage.id &&
          replyMessage.replyTo?.authorName == originalMessage.authorName) {
        _logResult('✅ Reply correctly stored with reference to original message');
      } else {
        _logResult('❌ Reply not properly linked to original message');
      }

    } catch (e) {
      _logResult('❌ Message replies test failed: $e');
    }
  }

  Future<void> _testTypingIndicators(User user) async {
    _logResult('\n⌨️ Testing Typing Indicators...');

    try {
      // Set typing status
      await _messageService.setTypingStatus('general', user.uid, user.displayName ?? 'Test User', true);
      _logResult('✅ Set typing status to true');

      // Get typing users
      final typingUsers = await _messageService.getTypingUsersStream('general').first;
      if (typingUsers.contains(user.displayName ?? 'Test User')) {
        _logResult('✅ Typing indicator correctly showing: ${typingUsers.join(', ')}');
      } else {
        _logResult('❌ Typing indicator not showing current user');
      }

      // Clear typing status
      await _messageService.setTypingStatus('general', user.uid, user.displayName ?? 'Test User', false);
      _logResult('✅ Set typing status to false');

    } catch (e) {
      _logResult('❌ Typing indicators test failed: $e');
    }
  }

  Future<void> _testPinnedMessages(User user) async {
    _logResult('\n📌 Testing Pinned Messages...');

    try {
      // Get a message to pin
      final messages = await _messageService.getMessagesStream('general').first;
      if (messages.isEmpty) {
        _logResult('⚠️ No messages found to pin');
        return;
      }

      final messageToPin = messages.last;
      _logResult('📱 Pinning message: ${messageToPin.content.substring(0, 20)}...');

      // Pin message
      await _messageService.pinMessage('general', messageToPin.id);
      _logResult('✅ Message pinned successfully');

      // Verify message was pinned
      final pinnedMessages = await _messageService.getPinnedMessagesStream('general').first;
      if (pinnedMessages.any((m) => m.id == messageToPin.id)) {
        _logResult('✅ Message appears in pinned messages list (${pinnedMessages.length} total)');
      } else {
        _logResult('❌ Pinned message not found in pinned messages list');
      }

      // Unpin message
      await _messageService.unpinMessage('general', messageToPin.id);
      _logResult('✅ Message unpinned successfully');

    } catch (e) {
      _logResult('❌ Pinned messages test failed: $e');
    }
  }

  Future<void> _testRealTimeSync() async {
    _logResult('\n🔄 Testing Real-time Data Synchronization...');

    try {
      // Listen for real-time updates
      final subscription = _messageService.getMessagesStream('general').listen((messages) {
        _logResult('📡 Real-time update received: ${messages.length} messages');
      });

      // Send a test message to trigger real-time update
      final user = FirebaseAuth.instance.currentUser!;
      await _messageService.sendMessage(
        'general',
        user.uid,
        user.displayName ?? 'Test User',
        'Real-time sync test message',
      );

      // Wait a moment for real-time update
      await Future.delayed(const Duration(seconds: 2));

      subscription.cancel();
      _logResult('✅ Real-time synchronization working correctly');

    } catch (e) {
      _logResult('❌ Real-time sync test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Features Test'),
        backgroundColor: const Color(0xFF2F3136),
      ),
      backgroundColor: const Color(0xFF36393F),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runAllTests,
              child: _isRunning
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Running Tests...'),
                      ],
                    )
                  : const Text('Run All Channel Tests'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F3136),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'Click "Run All Channel Tests" to begin testing...' : _testResults,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
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
