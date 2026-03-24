import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

class KickMemberDialog extends StatelessWidget {
  final String channelId;
  final String memberName;
  const KickMemberDialog({super.key, required this.channelId, required this.memberName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text('Kick Member', style: TextStyle(color: Colors.white)),
      content: Text('Are you sure you want to kick $memberName from the channel?', style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            // Note: Pass uid to service, here placeholder
            // Navigator.pop(context); 
            // await channelService.removeMember(channelId, memberUid); // integrate uid prop
          },
          child: const Text('Kick', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
