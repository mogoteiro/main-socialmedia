import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_tile.dart';
import 'user_profile_dialog.dart';
import '../config/app_constants.dart';

class SearchUserDialog extends StatefulWidget {
  const SearchUserDialog({super.key});

  @override
  State<SearchUserDialog> createState() => _SearchUserDialogState();
}

class _SearchUserDialogState extends State<SearchUserDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<QueryDocumentSnapshot> _results = [];
  String? _lastQuery;
  final Map<String, bool> _requested = {}; // uid -> requested
  final Set<String> _friends = {}; // uid set
  final Map<String, String> _incomingRequestIds = {}; // fromUid -> requestDocId
  List<QueryDocumentSnapshot> _friendDocs = []; // docs of current friends

  @override
  void initState() {
    super.initState();
    _loadFriendsOnInit();
  }

  Future<void> _loadFriendsOnInit() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').get();
      final friendUids = snap.docs.map((d) => d.id).toList();
      
      if (friendUids.isNotEmpty) {
        // Fetch full user docs for friends
        final userSnap = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendUids).get();
        setState(() {
          _friendDocs = userSnap.docs;
          _friends.addAll(friendUids);
          _results = _friendDocs;
        });
        
        // Refresh request states for friends
        await _refreshRequestStates(friendUids);
      }
    } catch (e) {
      debugPrint('Failed to load friends: $e');
    }
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; _lastQuery = q; });

    try {
      final coll = FirebaseFirestore.instance.collection('users');
      // prefix search on lowercase username
      final qLower = q.toLowerCase();
      final end = '$qLower\uf8ff';
      final snap = await coll.orderBy('username_lc').startAt([qLower]).endAt([end]).limit(50).get();
      setState(() { _results = snap.docs; });

      // refresh request/friend states for the result uids
      final uids = _results.map((d) => d.id).toList();
      _refreshFriendStates(uids);
      _refreshRequestStates(uids);
      _refreshIncomingRequests(uids);
    } catch (e) {
      setState(() { _error = 'Search failed: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _refreshFriendStates(List<String> uids) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').get();
      final myFriends = snap.docs.map((d) => d.id).toSet();
      setState(() {
        _friends.clear();
        for (final f in myFriends) {
          _friends.add(f);
        }
      });
    } catch (_) {}
  }

  Future<void> _refreshRequestStates(List<String> uids) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      // fetch pending requests FROM me and mark requested UIDs
      final snap = await FirebaseFirestore.instance.collection('friend_requests')
        .where('from', isEqualTo: me.uid)
        .where('status', isEqualTo: 'pending')
        .get();
      final requestedTo = snap.docs.map((d) => d.data()['to'] as String).toSet();
      setState(() {
        _requested.clear();
        for (final uid in uids) {
          _requested[uid] = requestedTo.contains(uid);
        }
      });
    } catch (_) {}
  }

  Future<void> _refreshIncomingRequests(List<String> uids) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('friend_requests')
        .where('to', isEqualTo: me.uid)
        .where('status', isEqualTo: 'pending')
        .get();
      final Map<String, String> incoming = {};
      for (final d in snap.docs) {
        final data = d.data();
        final from = data['from'] as String?;
        if (from != null && uids.contains(from)) incoming[from] = d.id;
      }
      setState(() {
        _incomingRequestIds.clear();
        _incomingRequestIds.addAll(incoming);
      });
    } catch (_) {}
  }

  Future<void> _sendFriendRequest(String toUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in')));
      return;
    }
    final fromUid = me.uid;
    if (fromUid == toUid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot add yourself')));
      return;
    }

    final requests = FirebaseFirestore.instance.collection('friend_requests');
    final existing = await requests.where('from', isEqualTo: fromUid).where('to', isEqualTo: toUid).get();
    if (existing.docs.isNotEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request already sent')));
      return;
    }

    // attempt to include sender info so recipient sees who requested
    String? fromUsername;
    String? fromDisplayName;
    try {
      final meDoc = await FirebaseFirestore.instance.collection('users').doc(fromUid).get();
      if (meDoc.exists) {
        final md = meDoc.data() as Map<String, dynamic>;
        fromUsername = md['username'] as String?;
        fromDisplayName = md['displayName'] as String?;
      }
    } catch (_) {}

    await requests.add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
    });

    setState(() { _requested[toUid] = true; });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
  }

  Future<void> _acceptIncoming(String reqId, String fromUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final batch = FirebaseFirestore.instance.batch();

    final myFriendRef = FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').doc(fromUid);
    final otherFriendRef = FirebaseFirestore.instance.collection('users').doc(fromUid).collection('friends').doc(me.uid);
    batch.set(myFriendRef, {'uid': fromUid, 'createdAt': FieldValue.serverTimestamp()});
    batch.set(otherFriendRef, {'uid': me.uid, 'createdAt': FieldValue.serverTimestamp()});

    final reqRef = FirebaseFirestore.instance.collection('friend_requests').doc(reqId);
    batch.update(reqRef, {'status': 'accepted', 'respondedAt': FieldValue.serverTimestamp()});

    await batch.commit();
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added')));
    final uids = _results.map((d) => d.id).toList();
    await _refreshFriendStates(uids);
    await _refreshRequestStates(uids);
    await _refreshIncomingRequests(uids);
  }

  Future<void> _declineIncoming(String reqId) async {
    try {
      await FirebaseFirestore.instance.collection('friend_requests').doc(reqId).update({'status': 'declined', 'respondedAt': FieldValue.serverTimestamp()});
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request declined')));
      final uids = _results.map((d) => d.id).toList();
      await _refreshIncomingRequests(uids);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  List<Widget> _buildUserList(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final username = data['username'] as String? ?? (data['displayName'] as String? ?? 'User');
      final email = data['email'] as String?;
      final uid = doc.id;
      final initial = (username.isNotEmpty ? username[0].toUpperCase() : 'U');
      final color = Colors.primaries[uid.hashCode % Colors.primaries.length];
      final isFriend = _friends.contains(uid);
      final isRequested = _requested[uid] == true;
      final incomingReqId = _incomingRequestIds[uid];
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => UserProfileDialog(
                      userName: username,
                      userId: uid,
                      userColor: color,
                      userServerPosts: const [],
                      selectedChannelIndex: 0,
                      channels: const ['General'],
                      isPersonal: false,
                      isFriend: isFriend,
                      onAddFriend: isFriend || isRequested || incomingReqId != null ? null : () => _sendFriendRequest(uid),
                      onBlock: () async {
                        final me = FirebaseAuth.instance.currentUser;
                        if (me == null) return;
                        final batch = FirebaseFirestore.instance.batch();
                        // add block record
                        final blockedRef = FirebaseFirestore.instance.collection('users').doc(me.uid).collection('blocked').doc(uid);
                        batch.set(blockedRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
                        // remove reciprocal friends
                        batch.delete(FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').doc(uid));
                        batch.delete(FirebaseFirestore.instance.collection('users').doc(uid).collection('friends').doc(me.uid));
                        await batch.commit();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked and removed from friends')));
                      },
                    ));
                  },
                  child: UserProfileTile(
                    userName: username,
                    userInitial: initial,
                    userColor: color,
                    subtitle: email,
                    isFriend: isFriend,
                    isRequested: isRequested,
                    onAddFriend: isFriend || isRequested || incomingReqId != null ? null : () => _sendFriendRequest(uid),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {'uid': uid, 'username': username}),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: AppColors.accentBlurple,
                  ),
                  child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
          if (incomingReqId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(onPressed: () => _acceptIncoming(incomingReqId, uid), child: const Text('Accept')),
                const SizedBox(width: 8),
                TextButton(onPressed: () => _declineIncoming(incomingReqId), child: const Text('Decline')),
              ]),
            ),
        ]),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _lastQuery != null && _lastQuery!.isNotEmpty;
    final displayResults = isSearching ? _results : _friendDocs;
    final hasResults = displayResults.isNotEmpty;
    
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Find Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Search username', filled: true, fillColor: Color(0xFF232328))),),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _loading ? null : _search, child: const Text('Search')),
          ],),
          const SizedBox(height: 12),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          if (!_loading && !hasResults && !isSearching)
            const Text(
              'Your Friends',
              style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          if (!_loading && !hasResults && isSearching)
            Text(
              'User not found: "${_lastQuery!}"',
              style: const TextStyle(color: Colors.white70),
            ),
          if (hasResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isSearching ? 'Search Results' : 'Your Friends',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          if (displayResults.isNotEmpty)
            ..._buildUserList(displayResults),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white70))),
        ],),
      ),
    );
  }
}
