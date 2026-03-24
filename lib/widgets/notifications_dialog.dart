import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_dialog.dart';
import '../config/app_constants.dart';

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return const Dialog(child: Padding(padding: EdgeInsets.all(20), child: Text('Sign in to see notifications')));
    final ref = FirebaseFirestore.instance.collection('users').doc(me.uid).collection('notifications').orderBy('createdAt', descending: true);
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      child: SizedBox(
        width: 520,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      // mark all as read
                      final snap = await FirebaseFirestore.instance.collection('users').doc(me.uid).collection('notifications').where('read', isEqualTo: false).get();
                      final batch = FirebaseFirestore.instance.batch();
                      for (final d in snap.docs) {
                        batch.update(d.reference, {'read': true});
                      }
                      await batch.commit();
                    },
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ref.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Error: \\${snap.error}'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('No notifications'));
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? 'message';
                      final from = data['from'] as String? ?? '';
                      final text = data['text'] as String? ?? '';
                      final read = data['read'] as bool? ?? false;
                      return ListTile(
                        tileColor: read ? null : Colors.grey[850],
                        title: Text(type == 'message' ? 'Message' : type, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(text, style: const TextStyle(color: Colors.white70)),
                        trailing: read ? null : const Icon(Icons.circle, size: 10, color: Colors.blueAccent),
                        onTap: () async {
                          // mark as read
                          await d.reference.update({'read': true});
                          // open sender profile / chat
                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(from).get();
                          final name = (userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['displayName'] as String? ?? (userDoc.data() as Map<String, dynamic>)['username'] as String? : null) ?? 'User';
                          // ignore: use_build_context_synchronously
                          showDialog(context: context, builder: (_) => UserProfileDialog(
                            userName: name,
                            userId: from,
                            userColor: Colors.primaries[from.hashCode % Colors.primaries.length],
                            userServerPosts: const [],
                            selectedChannelIndex: 0,
                            channels: const ['General'],
                            isPersonal: false,
                          ));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
