import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/channel_model.dart'; // reuse ChannelMember for server members

class ServerService {
  ServerService._();
  static final instance = ServerService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream server members
  Stream<List<ChannelMember>> getServerMembersStream(String serverId) {
    return _firestore.collection('servers').doc(serverId).snapshots().map((snap) {
      if (!snap.exists) return [];
      final data = snap.data()!;
      final membersData = data['members'] as List<dynamic>? ?? [];
      return membersData.map((m) => ChannelMember.fromMap(m as Map<String, dynamic>)).toList();
    });
  }

  /// Add member to server (similar to channel)
  Future<void> addMemberToServer(String serverId, String uid) async {
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

    // Add to server
    await _firestore.collection('servers').doc(serverId).update({
      'members': FieldValue.arrayUnion([member]),
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    
    // Add to default channels (create if not exists)
    final generalChannelRef = _firestore.collection('channels').doc('general');
    final generalExists = (await generalChannelRef.get()).exists;
    if (generalExists) {
      await generalChannelRef.update({
        'members': FieldValue.arrayUnion([member]),
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    } else {
      await generalChannelRef.set({
        'name': 'general',
        'members': [member],
        'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    final clipsChannelRef = _firestore.collection('channels').doc('clips-and-highlights');
    final clipsExists = (await clipsChannelRef.get()).exists;
    if (clipsExists) {
      await clipsChannelRef.update({
        'members': FieldValue.arrayUnion([member]),
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    } else {
      await clipsChannelRef.set({
        'name': 'clips-and-highlights',
        'members': [member],
        'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Remove member from server (kick)
  Future<void> removeMemberFromServer(String serverId, String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('User not logged in');

    final serverSnap = await _firestore.collection('servers').doc(serverId).get();
    if (!serverSnap.exists) throw Exception('Server not found');

    final data = serverSnap.data()!;
    final ownerId = data['ownerId'] as String? ?? '';
    if (currentUid != ownerId) throw Exception('Only owner can kick');

    final membersData = data['members'] as List<dynamic>? ?? [];
    final targetMember = membersData.firstWhere((m) => (m as Map<String, dynamic>)['uid'] == targetUid, orElse: () => null);
    if (targetMember == null) throw Exception('Member not found');

    final batch = _firestore.batch();
    final serverRef = _firestore.collection('servers').doc(serverId);
    batch.update(serverRef, {
      'members': FieldValue.arrayRemove([targetMember]),
      'memberUids': FieldValue.arrayRemove([targetUid]),
    });
    await batch.commit();
  }

  /// Create a new server
  Future<String> createServer(String name, String template, {String? logoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uid = user.uid;

    final serverRef = _firestore.collection('servers').doc();
    final serverId = serverRef.id;

    // Owner member
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final ownerData = userDoc.data() ?? {};
    final ownerName = ownerData['displayName'] ?? user.displayName ?? 'User';
    final ownerInitial = ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U';
    final ownerMember = ChannelMember(
      uid: uid,
      name: ownerName,
      initial: ownerInitial,
      colorIndex: uid.hashCode % 10,
      role: 'owner',
      joinedAt: Timestamp.now(),
    ).toMap();

    await serverRef.set({
      'name': name,
      'ownerId': uid,
      'template': template,
      'logoUrl': logoUrl ?? '',
      'members': [ownerMember],
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create default channels
    final generalChannelRef = _firestore.collection('channels').doc('general');
    if (!(await generalChannelRef.get()).exists) {
      await generalChannelRef.set({
        'name': 'general',
        'members': [ownerMember],
        'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final clipsChannelRef = _firestore.collection('channels').doc('clips-and-highlights');
    if (!(await clipsChannelRef.get()).exists) {
      await clipsChannelRef.set({
        'name': 'clips-and-highlights',
        'members': [ownerMember],
        'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    return serverId;
  }

  /// Create a new channel in a server
  Future<String> createChannel(String serverId, String channelName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uid = user.uid;

    // Generate unique channel ID
    final channelRef = _firestore.collection('channels').doc();
    final channelId = channelRef.id;

    // Get server to verify ownership
    final serverSnap = await _firestore.collection('servers').doc(serverId).get();
    if (!serverSnap.exists) throw Exception('Server not found');
    
    final serverData = serverSnap.data()!;
    final ownerId = serverData['ownerId'] as String?;
    if (ownerId != uid) throw Exception('Only server owner can create channels');

    // Get user info for channel member
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final userName = userData['displayName'] ?? user.displayName ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    
    final member = ChannelMember(
      uid: uid,
      name: userName,
      initial: userInitial,
      colorIndex: uid.hashCode % 10,
      role: 'owner',
      joinedAt: Timestamp.now(),
    ).toMap();

    // Create channel
    await channelRef.set({
      'name': channelName,
      'serverId': serverId,
      'members': [member],
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return channelId;
  }

  /// Delete server
  Future<void> deleteServer(String serverId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final serverSnap = await _firestore.collection('servers').doc(serverId).get();
    if (!serverSnap.exists) throw Exception('Server not found');

    final data = serverSnap.data()!;
    final ownerId = data['ownerId'] as String? ?? '';
    if (user.uid != ownerId) throw Exception('Only owner can delete server');

    // Delete the server document
    await _firestore.collection('servers').doc(serverId).delete();
  }

  /// Get all channels for a server
  Stream<List<Map<String, dynamic>>> getServerChannelsStream(String serverId) {
    return _firestore
        .collection('channels')
        .where('serverId', isEqualTo: serverId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              'name': doc['name'] ?? '',
              'createdAt': doc['createdAt'],
            }).toList());
  }
}
