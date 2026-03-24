import 'package:cloud_firestore/cloud_firestore.dart';

class Channel {
  final String id;
  final String name;
  final List<ChannelMember> members;

  Channel({
    required this.id,
    required this.name,
    required this.members,
  });

  factory Channel.fromMap(Map<String, dynamic> map, String id) {
    return Channel(
      id: id,
      name: map['name'] ?? '',
      members: (map['members'] as List<dynamic>?)
          ?.map((m) => ChannelMember.fromMap(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  Channel copyWith({
    String? id,
    String? name,
    List<ChannelMember>? members,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }
}

class ChannelMember {
  final String uid;
  final String name;
  final String initial;
  final int colorIndex;
  final String role; // 'owner', 'admin', 'member'
  final Timestamp? joinedAt;

  const ChannelMember({
    required this.uid,
    required this.name,
    required this.initial,
    required this.colorIndex,
    required this.role,
    this.joinedAt,
  });

  factory ChannelMember.fromMap(Map<String, dynamic> map) {
    return ChannelMember(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      initial: map['initial'] ?? '',
      colorIndex: map['colorIndex'] ?? 0,
      role: map['role'] ?? 'member',
      joinedAt: map['joinedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'initial': initial,
      'colorIndex': colorIndex,
      'role': role,
      'joinedAt': joinedAt,
    };
  }
}
