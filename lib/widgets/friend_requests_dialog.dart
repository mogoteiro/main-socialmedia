import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_tile.dart';
import '../config/app_constants.dart';

class FriendRequestsDialog extends StatefulWidget {
  const FriendRequestsDialog({super.key});

  @override
  State<FriendRequestsDialog> createState() => _FriendRequestsDialogState();
}

class _FriendRequestsDialogState extends State<FriendRequestsDialog> {

  Future<void> _accept(String reqId, String fromUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final batch = FirebaseFirestore.instance.batch();

    // add friend under both users
    final myFriendRef = FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').doc(fromUid);
    final otherFriendRef = FirebaseFirestore.instance.collection('users').doc(fromUid).collection('friends').doc(me.uid);
    batch.set(myFriendRef, {'uid': fromUid, 'createdAt': FieldValue.serverTimestamp()});
    batch.set(otherFriendRef, {'uid': me.uid, 'createdAt': FieldValue.serverTimestamp()});

    // update request status
    final reqRef = FirebaseFirestore.instance.collection('friend_requests').doc(reqId);
    batch.update(reqRef, {'status': 'accepted', 'respondedAt': FieldValue.serverTimestamp()});

    await batch.commit();
    // close the requests dialog and open Active Now view so user sees active list
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added')));
    // show ActiveNowDialog after the dialog has closed
    // ignore: use_build_context_synchronously
    Future.microtask(() => showDialog(context: context, builder: (_) => const ActiveNowDialog()));
  }

  Future<void> _decline(String reqId) async {
    try {
      await FirebaseFirestore.instance.collection('friend_requests').doc(reqId).update({'status': 'declined', 'respondedAt': FieldValue.serverTimestamp()});
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request declined')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  Widget _buildRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fromUid = data['from'] as String? ?? '';
    final username = data['fromUsername'] as String? ?? data['fromDisplayName'] as String? ?? 'User';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final color = Colors.primaries[fromUid.hashCode % Colors.primaries.length];

    return Row(
      children: [
        Expanded(
          child: UserProfileTile(
            userName: username,
            userInitial: initial,
            userColor: color,
            isFriend: false,
            onAddFriend: () {},
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: () => _accept(doc.id, fromUid), child: const Text('Accept')),
        const SizedBox(width: 8),
        TextButton(onPressed: () => _decline(doc.id), child: const Text('Decline')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return Dialog(
        backgroundColor: AppColors.cardBackground,
        child: Padding(padding: const EdgeInsets.all(16.0), child: const Text('Not signed in', style: TextStyle(color: Colors.white))),
      );
    }

    final stream = FirebaseFirestore.instance.collection('friend_requests')
        .where('to', isEqualTo: me.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) return Text('Failed loading requests: ${snap.error}', style: const TextStyle(color: Colors.redAccent));
            if (!snap.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));

            final docs = snap.data!.docs.toList();
            docs.sort((a, b) {
              final aa = (a.data() as Map<String, dynamic>)['createdAt'];
              final bb = (b.data() as Map<String, dynamic>)['createdAt'];
              if (aa == null && bb == null) return 0;
              if (aa == null) return 1;
              if (bb == null) return -1;
              return (bb as Timestamp).compareTo(aa as Timestamp);
            });

            return Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Friend Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (docs.isEmpty) const Text('No pending friend requests', style: TextStyle(color: Colors.white70)),
              if (docs.isNotEmpty) ...docs.map((d) => Padding(padding: const EdgeInsets.only(top:8.0), child: _buildRow(d))),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white70))),
            ]);
          },
        ),
      ),
    );
  }
}

class ActiveNowDialog extends StatefulWidget {
  const ActiveNowDialog({super.key});

  @override
  State<ActiveNowDialog> createState() => _ActiveNowDialogState();
}

class _ActiveNowDialogState extends State<ActiveNowDialog> {
  bool _loading = true;
  List<Map<String, String>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').get();
      final ids = snap.docs.map((d) => d.id).toList();
      final List<Map<String, String>> results = [];
      for (final id in ids) {
        final udoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (udoc.exists) {
          final data = udoc.data() as Map<String, dynamic>;
          results.add({'id': id, 'name': (data['displayName'] as String?) ?? (data['username'] as String?) ?? 'User'});
        }
      }
      setState(() { _friends = results; _loading = false; });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Active Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _friends.isEmpty) const Text("It's quiet for now...", style: TextStyle(color: Colors.white70)),
            if (!_loading && _friends.isNotEmpty)
              ..._friends.map((f) => ListTile(leading: const Icon(Icons.person, color: Colors.white), title: Text(f['name']!, style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white70))),
          ]),
        ),
      ),
    );
  }
}
