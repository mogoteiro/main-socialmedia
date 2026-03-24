import 'package:flutter/material.dart';
import '../config/app_constants.dart';

class UserProfileTile extends StatelessWidget {
  final String userName;
  final String userInitial;
  final Color userColor;
  final bool isFriend;
  final String? subtitle;
  final bool isRequested;
  final VoidCallback? onTap;
  final VoidCallback? onAddFriend;
  final VoidCallback? onBlock;

  const UserProfileTile({
    super.key,
    required this.userName,
    required this.userInitial,
    required this.userColor,
    this.isFriend = false,
    this.subtitle,
    this.isRequested = false,
    this.onTap,
    this.onAddFriend,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: userColor,
              child: Text(
                userInitial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (isFriend)
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[400],
                      ),
                    ),
                ],
              ),
            ),
            if (isFriend)
              IconButton(
                icon: const Icon(Icons.block, color: Colors.white),
                onPressed: onBlock,
                tooltip: 'Block',
              )
            else if (onAddFriend != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: isRequested
                    ? OutlinedButton(onPressed: null, child: const Text('Requested'))
                    : ElevatedButton(onPressed: onAddFriend, child: const Text('Add')),
              ),
          ],
        ),
      ),
    );
  }
}
