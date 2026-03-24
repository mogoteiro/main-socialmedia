import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../models/message_model.dart';

// Top-level function para sa compute (background processing)
Uint8List _compressImageBytesIsolate(Uint8List imageBytes) {
  try {
    // Decode image
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes; // Return original if decode fails
    
    // Resize if too large (max 1200px on longest side)
    img.Image resized = image;
    if (image.width > 1200 || image.height > 1200) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 1200 : null,
        height: image.height > image.width ? 1200 : null,
        interpolation: img.Interpolation.average,
      );
    }
    
    // Encode as JPEG with quality 80 for smaller file size
    final compressed = img.encodeJpg(resized, quality: 80);
    return Uint8List.fromList(compressed);
  } catch (e) {
    // If compression fails, return original
    return imageBytes;
  }
}

class MessageService {
  MessageService._();
  static final instance = MessageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Compress image bytes to reduce file size
  Future<Uint8List> _compressImageBytes(Uint8List imageBytes) async {
    // Use compute to run compression in a separate isolate preventing UI freeze
    return await compute(_compressImageBytesIsolate, imageBytes);
  }

  /// Compress image file
  Future<File> _compressImageFile(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final compressed = await _compressImageBytes(bytes);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressed);
      return tempFile;
    } catch (e) {
      // If compression fails, return original
      return imageFile;
    }
  }

  /// Upload image bytes to Firebase Storage (for web)
  Future<String> uploadImageBytesToStorage(String channelId, Uint8List imageBytes, {String fileName = 'image.png'}) async {
    try {
      // Compress image first
      final compressed = await _compressImageBytes(imageBytes);
      
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final storageRef = _storage.ref().child('channels/$channelId/messages/$uniqueFileName');
      
      // Upload with extended timeout and retry logic
      int retries = 0;
      const maxRetries = 2;
      
      while (retries < maxRetries) {
        try {
          await storageRef.putData(compressed).timeout(
            const Duration(seconds: 180),
            onTimeout: () => throw Exception('Image upload timed out'),
          );
          break; // Success
        } catch (e) {
          retries++;
          if (retries >= maxRetries) rethrow;
          await Future.delayed(Duration(seconds: 2 * retries));
        }
      }
      
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload image to Firebase Storage (for native)
  Future<String> uploadImageToStorage(String channelId, File imageFile) async {
    try {
      // Compress image first
      final compressed = await _compressImageFile(imageFile);
      
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final storageRef = _storage.ref().child('channels/$channelId/messages/$uniqueFileName');
      
      // Upload with extended timeout and retry logic
      int retries = 0;
      const maxRetries = 2;
      
      while (retries < maxRetries) {
        try {
          await storageRef.putFile(compressed).timeout(
            const Duration(seconds: 180),
            onTimeout: () => throw Exception('Image upload timed out'),
          );
          break; // Success
        } catch (e) {
          retries++;
          if (retries >= maxRetries) rethrow;
          await Future.delayed(Duration(seconds: 2 * retries));
        }
      }
      
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Send a message to a channel
  Future<void> sendMessage(String channelId, String authorId, String authorName, String content) async {
    // Parse mentions from content
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);
    final mentions = matches.map((match) => match.group(1)!).toSet().toList();

    final message = Message(
      id: '', // Will be set by Firestore
      channelId: channelId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      timestamp: DateTime.now(),
      mentions: mentions,
    );

    await _firestore.collection('channels').doc(channelId).collection('messages').add(message.toMap());
  }

  /// Send message with optional image URL
  Future<void> sendMessageWithImage(String channelId, String authorId, String authorName, String content, {String? imageUrl}) async {
    // Parse mentions from content
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);
    final mentions = matches.map((match) => match.group(1)!).toSet().toList();

    final message = Message(
      id: '', // Will be set by Firestore
      channelId: channelId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      mentions: mentions,
    );

    await _firestore.collection('channels').doc(channelId).collection('messages').add(message.toMap());
  }

  /// Send message with image file (for native platforms)
  Future<void> sendMessageWithImageFile(String channelId, String authorId, String authorName, String content, File imageFile) async {
    final imageUrl = await uploadImageToStorage(channelId, imageFile);
    await sendMessageWithImage(channelId, authorId, authorName, content, imageUrl: imageUrl);
  }

  /// Send message with image bytes (for web)
  Future<void> sendMessageWithImageBytes(String channelId, String authorId, String authorName, String content, Uint8List imageBytes) async {
    final imageUrl = await uploadImageBytesToStorage(channelId, imageBytes);
    await sendMessageWithImage(channelId, authorId, authorName, content, imageUrl: imageUrl);
  }

  /// Get a stream of messages for a channel, ordered by timestamp
  Stream<List<Message>> getMessagesStream(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList());
  }

  /// Get a stream of replies for a specific message (Thread View)
  Stream<List<Message>> getRepliesStream(String channelId, String parentMessageId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .where('replyTo.messageId', isEqualTo: parentMessageId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Edit a message
  Future<void> editMessage(String channelId, String messageId, String newContent) async {
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({
          'content': newContent,
          'isEdited': true,
        });
  }

  /// Delete a message
  Future<void> deleteMessage(String channelId, String messageId) async {
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Add reaction to a message
  Future<void> addReaction(String channelId, String messageId, String emoji, String userId) async {
    final messageRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final messageDoc = await transaction.get(messageRef);
      if (!messageDoc.exists) return;

      final currentReactions = (messageDoc.data()?['reactions'] as List<dynamic>? ?? [])
          .map((r) => MessageReaction.fromMap(r as Map<String, dynamic>))
          .toList();

      // Enforce one reaction per user: remove user from all other reactions.
      for (var reaction in currentReactions) {
        reaction.userIds.remove(userId);
      }

      // Find the target reaction and add the user.
      var targetReaction = currentReactions.firstWhere(
        (r) => r.emoji == emoji,
        orElse: () {
          final newReaction = MessageReaction(emoji: emoji, userIds: []);
          currentReactions.add(newReaction);
          return newReaction;
        },
      );

      if (!targetReaction.userIds.contains(userId)) {
        targetReaction.userIds.add(userId);
      }

      // Filter out reactions with no users and convert back to map for Firestore.
      final updatedReactionsData = currentReactions
          .where((r) => r.userIds.isNotEmpty)
          .map((r) => r.toMap())
          .toList();

      transaction.update(messageRef, {'reactions': updatedReactionsData});
    });
  }

  /// Remove reaction from a message
  Future<void> removeReaction(String channelId, String messageId, String emoji, String userId) async {
    final messageRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final messageDoc = await transaction.get(messageRef);
      final currentReactions = messageDoc['reactions'] as List<dynamic>? ?? [];

      List<dynamic> updatedReactions = [];
      for (final reaction in currentReactions) {
        if (reaction['emoji'] == emoji) {
          List<String> userIds = List.from((reaction['userIds'] as List<dynamic>?) ?? []).cast<String>();
          userIds.remove(userId);
          if (userIds.isNotEmpty) {
            updatedReactions.add({
              'emoji': emoji,
              'userIds': userIds,
            });
          }
        } else {
          updatedReactions.add(reaction);
        }
      }

      transaction.update(messageRef, {'reactions': updatedReactions});
    });
  }

  /// Send message with reply
  Future<void> sendMessageWithReply(
    String channelId,
    String authorId,
    String authorName,
    String content, {
    String? imageUrl,
    String? replyToMessageId,
    String? replyToAuthorName,
    String? replyToContent,
    List<String> attachments = const [],
  }) async {
    // Parse mentions from content
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);
    final mentions = matches.map((match) => match.group(1)!).toSet().toList();

    MessageReply? replyTo;
    if (replyToMessageId != null && replyToAuthorName != null && replyToContent != null) {
      replyTo = MessageReply(
        messageId: replyToMessageId,
        authorName: replyToAuthorName,
        content: replyToContent,
      );
    }

    final message = Message(
      id: '', // Will be set by Firestore
      channelId: channelId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      attachments: attachments,
      replyTo: replyTo,
      mentions: mentions,
    );

    await _firestore.collection('channels').doc(channelId).collection('messages').add(message.toMap());
  }

  /// Pin a message
  Future<void> pinMessage(String channelId, String messageId) async {
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isPinned': true,
          'pinnedAt': Timestamp.now(),
        });
  }

  /// Unpin a message
  Future<void> unpinMessage(String channelId, String messageId) async {
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isPinned': false,
          'pinnedAt': null,
        });
  }

  /// Get pinned messages for a channel
  Stream<List<Message>> getPinnedMessagesStream(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data(), doc.id))
          .toList();
      // Sort client-side to avoid Firestore index requirement
      messages.sort((a, b) {
        return (b.pinnedAt ?? DateTime(0)).compareTo(a.pinnedAt ?? DateTime(0));
      });
      return messages;
    });
  }

  /// Set user typing status
  Future<void> setTypingStatus(String channelId, String userId, String userName, bool isTyping) async {
    if (isTyping) {
      await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('typingIndicators')
          .doc(userId)
          .set({
            'userName': userName,
            'timestamp': Timestamp.now(),
          });
    } else {
      await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('typingIndicators')
          .doc(userId)
          .delete();
    }
  }

  /// Get typing users stream
  Stream<List<String>> getTypingUsersStream(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('typingIndicators')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final typingUsers = <String>[];
      for (final doc in snapshot.docs) {
        final timestamp = (doc['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        // Remove typing indicator after 3 seconds of inactivity
        if (now.difference(timestamp).inSeconds < 3) {
          typingUsers.add(doc['userName']);
        } else {
          // Clean up stale typing indicators
          doc.reference.delete();
        }
      }
      return typingUsers;
    });
  }
}