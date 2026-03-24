import 'package:flutter/material.dart';

class PostCard {
  final String id;
  final String author;
  final String authorInitial;
  final String timestamp;
  final String content;
  final String description;
  final Color avatarColor;
  final int likes;
  final int channelIndex;
  final String? gifUrl;
  final String? imageUrl;

  PostCard({
    required this.id,
    required this.author,
    required this.authorInitial,
    required this.timestamp,
    required this.content,
    required this.description,
    required this.avatarColor,
    required this.likes,
    required this.channelIndex,
    this.gifUrl,
    this.imageUrl,
  });

  PostCard copyWith({
    String? id,
    String? author,
    String? authorInitial,
    String? timestamp,
    String? content,
    String? description,
    Color? avatarColor,
    int? likes,
    int? channelIndex,
    String? gifUrl,
    String? imageUrl,
  }) {
    return PostCard(
      id: id ?? this.id,
      author: author ?? this.author,
      authorInitial: authorInitial ?? this.authorInitial,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      description: description ?? this.description,
      avatarColor: avatarColor ?? this.avatarColor,
      likes: likes ?? this.likes,
      channelIndex: channelIndex ?? this.channelIndex,
      gifUrl: gifUrl ?? this.gifUrl,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class UserProfile {
  final String name;
  final String initial;
  final Color color;
  final List<PostCard> posts;

  UserProfile({
    required this.name,
    required this.initial,
    required this.color,
    required this.posts,
  });
}
