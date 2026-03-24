import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_constants.dart';
import '../../services/channel_service.dart';
import '../../models/channel_model.dart';
// import 'kick_member_dialog.dart'; // optional confirm
import 'search_user_dialog.dart';

class ChannelMembersDialog extends StatefulWidget {
  final String channelId;
  final String channelName;
  const ChannelMembersDialog({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelMembersDialog> createState() => _ChannelMembersDialogState();
}

class _ChannelMembersDialogState extends State<ChannelMembersDialog> {
  final ChannelService _channelService = ChannelService.instance;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Dialog(
      backgroundColor: AppColors.background,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('# ${widget.channelName} Members', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<Channel>(
                stream: _channelService.getChannelStream(widget.channelId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('No members', style: TextStyle(color: Colors.white70)));
                  }
                  final channel = snapshot.data!;
                  final members = channel.members;
                  
                  if (members.isEmpty) {
                    return const Center(child: Text('No members yet', style: TextStyle(color: Colors.white70)));
                  }
                  
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isOwner = member.role == 'owner';
                      final isSelf = member.uid == currentUid;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[member.colorIndex % Colors.primaries.length],
                          child: Text(member.initial, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(member.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(member.role.toUpperCase(), style: TextStyle(color: Colors.white70)),
                        trailing: !isSelf && currentUid.isNotEmpty && isOwner 
                          ? IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                              onPressed: () async {
                                try {
                                  await _channelService.removeMember(widget.channelId, member.uid);
                                  // ignore: use_build_context_synchronously
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member kicked')));
                                } catch (e) {
                                  // ignore: use_build_context_synchronously
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              },
                            )
                          : null,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Member'),
                    onPressed: () {
                      showDialog(context: context, builder: (_) => const SearchUserDialog()).then((result) async {
                        if (result != null && result is Map<String, dynamic>) {
                          final selectedUid = result['uid'] as String?;
                          final selectedUsername = result['username'] as String?;
                          if (selectedUid != null && selectedUsername != null) {
                            try {
                              await _channelService.addMember(widget.channelId, selectedUid);
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$selectedUsername added to channel')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error adding member: $e')),
                                );
                              }
                            }
                          }
                        }
                      });
                    },
                  ),
                ), 
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
