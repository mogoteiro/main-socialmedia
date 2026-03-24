import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'widgets/user_profile_dialog.dart';
import 'widgets/notifications_dialog.dart';
import 'widgets/create_server_dialog.dart';
import 'screens/server_screen.dart';
import 'widgets/friend_requests_dialog.dart';
import 'config/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp() failed: $e');
  }

  runApp(const SocialCordApp());
}

class SocialCordApp extends StatelessWidget {
  const SocialCordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocialCord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginPage(),
        '/home': (_) => const SocialCordHome(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

class SocialCordHome extends StatefulWidget {
  const SocialCordHome({super.key});

  @override
  State<SocialCordHome> createState() => _SocialCordHomeState();
}

class _SocialCordHomeState extends State<SocialCordHome> {
  String currentUserName = 'You';
  String currentUserInitial = 'Y';
  final Color currentUserColor = Colors.blueAccent;
  // servers are loaded from Firestore; no in-memory storage
  final TextEditingController _friendCtrl = TextEditingController();
  // Unified layout for all users; do not branch UI for new users
  // friend data intentionally hidden for new presentation
  // channels and posts removed for new-user presentation

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _friendCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Try to get user data from Firestore
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final displayName = data['displayName'] as String? ?? '';
          final username = data['username'] as String? ?? '';
          
          setState(() {
            currentUserName = displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : 'User');
            currentUserInitial = currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : 'U';
          });
        } else {
          // Fallback to Firebase Auth display name
          setState(() {
            currentUserName = user.displayName ?? 'User';
            currentUserInitial = currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : 'U';
          });
        }
      } catch (e) {
        // Fallback to Firebase Auth display name
        setState(() {
          currentUserName = user.displayName ?? 'User';
          currentUserInitial = currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : 'U';
        });
      }
    }
  }

  void _showYourProfileDialog() {
    final me = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(
        userName: currentUserName,
        userId: me?.uid ?? '',
        userColor: currentUserColor,
        userServerPosts: const [],
        selectedChannelIndex: 0,
        channels: const ['General'],
        isPersonal: true,
      ),
    );
  }

  void _openServer(String serverId, String serverName, String? logoUrl) {
Navigator.push(context, MaterialPageRoute(builder: (_) => ServerScreen(serverId: serverId, serverName: serverName, logoUrl: logoUrl)));
  }

  Future<void> _handleSendFriendRequest() async {
    final q = _friendCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a username')));
      return;
    }

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in')));
      return;
    }

    // support username#1234 style by stripping tag
    final raw = q.split('#').first.trim();
    final usernameLc = raw.toLowerCase();

    try {
      final coll = FirebaseFirestore.instance.collection('users');
      var snap = await coll.where('username_lc', isEqualTo: usernameLc).limit(1).get();
      if (snap.docs.isEmpty) {
        // Fallback: some user documents may not have `username_lc`. Try exact `username` match.
        snap = await coll.where('username', isEqualTo: raw).limit(1).get();
        if (snap.docs.isEmpty) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
          return;
        }
      }

      final toDoc = snap.docs.first;
      final toUid = toDoc.id;
      if (toUid == me.uid) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot add yourself')));
        return;
      }

      final requests = FirebaseFirestore.instance.collection('friend_requests');
      final existing = await requests.where('from', isEqualTo: me.uid).where('to', isEqualTo: toUid).get();
      if (existing.docs.isNotEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request already sent')));
        return;
      }

      // include sender info for clarity to the recipient
      String? fromUsername;
      String? fromDisplayName;
      try {
        final meDoc = await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
        if (meDoc.exists) {
          final md = meDoc.data() as Map<String, dynamic>;
          fromUsername = md['username'] as String?;
          fromDisplayName = md['displayName'] as String?;
        }
      } catch (_) {}

      await requests.add({
        'from': me.uid,
        'to': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'fromUsername': fromUsername,
        'fromDisplayName': fromDisplayName,
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
      _friendCtrl.clear();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    }
  }

  // No initState or resend verification — show same UI for new and returning users

  // create-post placeholder removed; posts are shown in the Posts section

  // create-channel flow removed

  // Helper sections removed — unified new-user style UI is rendered for all users.

  // channels UI removed

  // posts view removed

  // common-friends per channel removed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SocialCord'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: _showYourProfileDialog,
            borderRadius: BorderRadius.circular(25),
            child: CircleAvatar(
              backgroundColor: currentUserColor,
              child: Text(
                currentUserInitial,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
        actions: [
          // Notifications badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser == null
                ? const Stream.empty()
                : FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).collection('notifications').where('read', isEqualTo: false).snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return IconButton(
                onPressed: () => showDialog(context: context, builder: (_) => const NotificationsDialog()),
                icon: Stack(children: [
                  const Icon(Icons.notifications),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(child: Text('$count', style: const TextStyle(fontSize: 10))),
                      ),
                    ),
                ]),
              );
            },
          ),

          // Friend requests badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friend_requests')
                .where('to', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return IconButton(
                onPressed: () => showDialog(context: context, builder: (_) => const FriendRequestsDialog()),
                icon: Stack(children: [
                  const Icon(Icons.person),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(child: Text('$count', style: const TextStyle(fontSize: 10))),
                      ),
                    ),
                ]),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left sidebar: single server-creator circle
                SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // render existing servers
                      // Load servers from Firestore for current user
                      StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, authSnap) {
                          final me = authSnap.data;
                          if (me == null) return const SizedBox.shrink();
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('servers').where('memberUids', arrayContains: me.uid).snapshots(),
                            builder: (context, snap) {
                              if (snap.hasError) return const SizedBox.shrink();
                              if (!snap.hasData) return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()));
                              final docs = snap.data!.docs;
                              return Column(
                                children: docs.map((d) {
                                  final data = d.data() as Map<String, dynamic>;
                                  final name = data['name'] as String? ?? 'Server';
                                  final logo = data['logoUrl'] as String?;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: InkWell(
                                      onTap: () => _openServer(d.id, name, logo),
                                      child: CircleAvatar(radius: 20, backgroundColor: Colors.grey[700], child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S')),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // create server button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => showDialog(
                            context: context,
                            builder: (context) => CreateServerDialog(),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[700],
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // main content: Add Friend + empty-friends state
                Expanded(
                  flex: 3,
                  child: Card(
                    color: AppColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Friend', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text('You can add friends with their Discord username.'),
                          const SizedBox(height: 12),
                          TextFormField(controller: _friendCtrl, decoration: const InputDecoration(hintText: 'Enter username#1234')),
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _handleSendFriendRequest, child: const Text('Send Friend Request'))),
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => const FriendRequestsDialog()), child: const Text('Friend Requests'))),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          // Empty friends state
                          Center(
                            child: Column(
                              children: const [
                                Icon(Icons.person_off, size: 48, color: Colors.white24),
                                SizedBox(height: 12),
                                Text('You don\'t have any friends yet', style: TextStyle(color: Colors.white70)),
                                SizedBox(height: 6),
                                Text('Add friends with their username to get started', style: TextStyle(color: Colors.white38)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Other Places to Make Friends', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Card(
                            color: Colors.grey[850],
                            child: ListTile(
                              leading: const Icon(Icons.explore, color: Colors.white),
                              title: const Text('Explore Discoverable Servers', style: TextStyle(color: Colors.white)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.white),
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // right column: Active Now (shows friends)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Card(
                        color: AppColors.cardBackground,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active Now', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              StreamBuilder<User?>(
                                stream: FirebaseAuth.instance.authStateChanges(),
                                builder: (context, authSnap) {
                                  final me = authSnap.data;
                                  if (me == null) return const Text('Sign in to see friends', style: TextStyle(color: Colors.white70));
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').snapshots(),
                                    builder: (context, snap) {
                                      if (snap.hasError) return Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white70));
                                      if (!snap.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                                      final docs = snap.data!.docs;
                                      if (docs.isEmpty) return const Text("It's quiet for now...", style: TextStyle(color: Colors.white70));
                                      return Column(
                                        children: docs.map((d) {
                                          final friendId = d.id;
                                          return FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                                            builder: (context, userSnap) {
                                              final name = (userSnap.hasData && userSnap.data!.exists)
                                                ? ((userSnap.data!.data() as Map<String, dynamic>)['displayName'] as String? ?? (userSnap.data!.data() as Map<String, dynamic>)['username'] as String? ?? 'User')
                                                : 'User';
                                              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                                              return ListTile(
                                                leading: CircleAvatar(backgroundColor: Colors.primaries[friendId.hashCode % Colors.primaries.length], child: Text(initial)),
                                                title: Text(name, style: const TextStyle(color: Colors.white)),
                                                onTap: () {
                                                  // open user profile dialog (friend)
                                                  showDialog(context: context, builder: (_) => UserProfileDialog(
                                                    userName: name,
                                                    userId: friendId,
                                                    userColor: Colors.primaries[friendId.hashCode % Colors.primaries.length],
                                                    userServerPosts: const [],
                                                    selectedChannelIndex: 0,
                                                    channels: const ['General'],
                                                    isPersonal: false,
                                                    isFriend: true,
                                                    onBlock: () async {
                                                      final me = FirebaseAuth.instance.currentUser;
                                                      if (me == null) return;
                                                      final batch = FirebaseFirestore.instance.batch();
                                                      // Add blocked record for current user
                                                      final blockedRef = FirebaseFirestore.instance.collection('users').doc(me.uid).collection('blocked').doc(friendId);
                                                      batch.set(blockedRef, {'uid': friendId, 'createdAt': FieldValue.serverTimestamp()});
                                                      // remove reciprocal friends
                                                      batch.delete(FirebaseFirestore.instance.collection('users').doc(me.uid).collection('friends').doc(friendId));
                                                      batch.delete(FirebaseFirestore.instance.collection('users').doc(friendId).collection('friends').doc(me.uid));
                                                      await batch.commit();
                                                      if (!mounted) return;
                                                      // ignore: use_build_context_synchronously
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked and removed from friends')));
                                                    },
                                                  ));
                                                },
                                              );
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
