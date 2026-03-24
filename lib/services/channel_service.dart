import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/channel_model.dart';

class ChannelService {
  ChannelService._();
  static final instance = ChannelService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update channel name
  Future<void> updateChannelName(String channelId, String newName) async {
    await _firestore.collection('channels').doc(channelId).update({'name': newName});
  }

  /// Delete channel (also handles messages subcollection if needed)
  Future<void> deleteChannel(String channelId) async {
    await _firestore.collection('channels').doc(channelId).delete();
  }

  /// Stream channel data
  Stream<Channel> getChannelStream(String channelId) {
    return _firestore.collection('channels').doc(channelId).snapshots().map((snap) {
      if (!snap.exists) return Channel(id: channelId, name: '', members: []);
      return Channel.fromMap(snap.data()!, channelId);
    });
  }

  /// Add member to channel
  Future<void> addMember(String channelId, String uid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) throw Exception('User not found');

    final data = userDoc.data()!;
    final name = data['displayName'] ?? data['username'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final colorIndex = uid.hashCode % 10;

    final member = ChannelMember(
      uid: uid,
      name: name,
      initial: initial,
      colorIndex: colorIndex,
      role: 'member',
      joinedAt: Timestamp.now(),
    ).toMap();

    await _firestore.collection('channels').doc(channelId).update({
      'members': FieldValue.arrayUnion([member]),
      'memberUids': FieldValue.arrayUnion([uid]),
    });
  }

  /// Remove (kick) member from channel
  Future<void> removeMember(String channelId, String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('User not logged in');

    // Get channel to check permissions
    final channelSnap = await _firestore.collection('channels').doc(channelId).get();
    if (!channelSnap.exists) throw Exception('Channel not found');

    final channel = Channel.fromMap(channelSnap.data()!, channelId);
    final ownerMember = channel.members.firstWhere((m) => m.role == 'owner', orElse: () => channel.members.isNotEmpty ? channel.members.first : throw Exception('No owner'));
    final ownerUid = ownerMember.uid;

    if (currentUid != ownerUid) throw Exception('Only owner can kick members');

    if (targetUid == currentUid) {
      // Self-leave
      final selfMember = channel.members.firstWhere((m) => m.uid == targetUid);
      final batch = _firestore.batch();
      final channelRef = _firestore.collection('channels').doc(channelId);
      batch.update(channelRef, {
        'members': FieldValue.arrayRemove([selfMember.toMap()]),
        'memberUids': FieldValue.arrayRemove([targetUid]),
      });
      await batch.commit();
    } else {
      // Kick other
      final targetMember = channel.members.firstWhere((m) => m.uid == targetUid);
      final batch = _firestore.batch();
      final channelRef = _firestore.collection('channels').doc(channelId);
      batch.update(channelRef, {
        'members': FieldValue.arrayRemove([targetMember.toMap()]),
        'memberUids': FieldValue.arrayRemove([targetUid]),
      });
      await batch.commit();
    }
  }

  /// Stream of channels for a server (future use; assumes servers/{serverId}/channels)
  /// Placeholder for future dynamic channels
  Stream<List<Channel>> getChannelsStream(String serverId) {
    return const Stream.empty();
  }
}
