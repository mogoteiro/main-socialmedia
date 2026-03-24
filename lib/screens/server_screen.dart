// Import: flutter/material.dart - UI widgets
// Import: config/app_constants.dart - Colors/constants
// Import: services/server_service.dart & channel_service.dart - Data streams for servers/channels/members
// Import: widgets/*_dialog.dart - Dialogs for create/rename/delete/kick/search
// Import: screens/channel_screen.dart & voice_chat_screen.dart - Navigation to chat/voice
import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../services/server_service.dart';
import '../services/channel_service.dart';
import '../widgets/search_user_dialog.dart';
import '../widgets/rename_channel_dialog.dart';
import '../widgets/delete_channel_dialog.dart';
import '../widgets/channel_members_dialog.dart';
import '../widgets/rename_server_dialog.dart';
import '../widgets/delete_server_dialog.dart';
import '../widgets/create_channel_dialog.dart';
import 'channel_screen.dart';
import 'voice_chat_screen.dart';

// Widget: ServerScreen
// Gamit: Main screen ng server na may channels list, voice channels, members, quick start.
// Connected sa: server_service/channel_service (streams), multiple dialogs, channel_screen/voice_chat_screen.
class ServerScreen extends StatefulWidget {
  final String serverId;
  final String serverName;
  final String? logoUrl;
  final bool showQuickStart;
  const ServerScreen({super.key, required this.serverId, required this.serverName, this.logoUrl, this.showQuickStart = true});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

// State Class: _ServerScreenState
// Gamit: Manage UI state for channels/members streams, dialogs, navigation.
class _ServerScreenState extends State<ServerScreen> {

  Widget _actionTile(IconData icon, String title) {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: () {},
      ),
    );
  }

  Widget _buildChannelMenu(String channelId, String channelName) {
    return PopupMenuButton<String>(
      color: AppColors.cardBackground,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Rename channel')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 8), Text('Delete channel', style: TextStyle(color: Colors.redAccent))])),
      ],
      onSelected: (value) {
        if (value == 'rename') {
showDialog(context: context, builder: (_) => RenameChannelDialog(channelId: channelId, currentName: channelName));
        } else if (value == 'delete') {
showDialog(context: context, builder: (_) => DeleteChannelDialog(channelId: channelId, channelName: channelName));
        }
      },
    );
  }

  void _showServerSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Server Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Rename Server'),
              onTap: () {
                Navigator.pop(context);
showDialog(context: context, builder: (_) => RenameServerDialog(serverId: widget.serverId, currentName: widget.serverName));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: const Text('Kick Member'),
              subtitle: const Text('Manage server members', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                showDialog(context: context, builder: (_) => const ChannelMembersDialog(channelId: 'general', channelName: 'general'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete Server'),
              subtitle: const Text('Permanently delete this server', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                showDialog(context: context, builder: (_) => DeleteServerDialog(serverId: widget.serverId, serverName: widget.serverName));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _joinVoiceChannel(String channelId, String channelName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceChatScreen(
          channelId: '${widget.serverId}_voice_$channelId',
          channelName: channelName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
              CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(widget.logoUrl!),
                backgroundColor: Colors.transparent,
              ),
            if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty) const SizedBox(width: 8),
            Text(widget.serverName, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Row(
        children: [
          // server sidebar
          Container(
            width: 72,
            color: const Color(0xFF2A2D31),
            child: Column(
              children: [
                const SizedBox(height: 12),
                CircleAvatar(radius: 20, backgroundColor: Colors.purple, child: Text(widget.serverName.isNotEmpty ? widget.serverName[0].toUpperCase() : 'S')),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // left panel: channels
          Container(
            width: 260,
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.serverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => _showServerSettings(context),
                        icon: const Icon(Icons.settings, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Text Channels', style: TextStyle(color: Colors.white70)),
                      IconButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => CreateChannelDialog(serverId: widget.serverId),
                        ),
                        icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Load channels dynamically
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ServerService.instance.getServerChannelsStream(widget.serverId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        final generalId = '${widget.serverId}_general';
                        final clipsId = '${widget.serverId}_clips-and-highlights';
                        // Fallback to default channels
                        return Column(
                          children: [
                            Card(color: Colors.grey[850], child: ListTile(
                              title: const Text('# general', style: TextStyle(color: Colors.white)),
                              trailing: _buildChannelMenu(generalId, 'general'),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(channelId: generalId, channelName: 'general'))),
                            )),
                            const SizedBox(height: 8),
                            Card(color: Colors.grey[850], child: ListTile(
                              title: const Text('# clips-and-highlights', style: TextStyle(color: Colors.white)),
                              trailing: _buildChannelMenu(clipsId, 'clips-and-highlights'),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(channelId: clipsId, channelName: 'clips-and-highlights'))),
                            )),
                          ],
                        );
                      }
                      
                      final channels = snapshot.data!;
                      if (channels.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No channels yet. Create one!', style: TextStyle(color: Colors.white70)),
                          ),
                        );
                      }
                      
                      return Column(
                        children: channels.map((channel) {
                          final channelId = channel['id'] as String;
                          final channelName = channel['name'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              color: Colors.grey[850],
                              child: ListTile(
                                title: Text('# $channelName', style: const TextStyle(color: Colors.white)),
                                trailing: _buildChannelMenu(channelId, channelName),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChannelScreen(
                                      channelId: channelId,
                                      channelName: channelName,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Voice Channels', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Card(color: Colors.grey[850], child: ListTile(
                    leading: const Icon(Icons.volume_up, color: Colors.white), 
                    title: const Text('Lobby', style: TextStyle(color: Colors.white)),
                    onTap: () => _joinVoiceChannel('lobby', 'Lobby'),
                  )),
                  const SizedBox(height: 8),
                  Card(color: Colors.grey[850], child: ListTile(
                    leading: const Icon(Icons.volume_up, color: Colors.white), 
                    title: const Text('Gaming', style: TextStyle(color: Colors.white)),
                    onTap: () => _joinVoiceChannel('gaming', 'Gaming'),
                  )),
                ],
              ),
            ),
          ),
          // center: welcome / quick-start
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: widget.showQuickStart
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Welcome to', style: TextStyle(fontSize: 22, color: AppColors.lightGrey400)),
                          const SizedBox(height: 8),
                          Text(widget.serverName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          const Text('This is your brand new, shiny server. Here are some steps to help you get started.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 24),
                          Card(
                            color: AppColors.cardBackground,
                            child: ListTile(
                              leading: const Icon(Icons.person_add, color: Colors.white),
                              title: const Text('Invite your friends', style: TextStyle(color: Colors.white)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                              onTap: () {
                                showDialog(context: context, builder: (_) => const SearchUserDialog()).then((result) async {
                                  if (result != null && result is Map<String, dynamic>) {
                                    final selectedUid = result['uid'] as String?;
                                    final selectedUsername = result['username'] as String?;
                                    if (selectedUid != null && selectedUsername != null) {
                                      try {
                                        await ServerService.instance.addMemberToServer(widget.serverId, selectedUid);
                                        if (mounted) {
                                          // ignore: use_build_context_synchronously
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$selectedUsername added to server')),
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
                          _actionTile(Icons.image, 'Personalize your server with an icon'),
                          _actionTile(Icons.message, 'Send your first message'),
                          _actionTile(Icons.extension, 'Add your first app'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.serverName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          const Text('Welcome back!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                        ],
                      ),
              ),
            ),
          ),
          // right: members panel - for general channel
          Container(
            width: 300,
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Members (# general)', style: TextStyle(color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.group, color: Colors.white),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const ChannelMembersDialog(channelId: 'general', channelName: 'general'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder(
                      stream: ChannelService.instance.getChannelStream('general'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Text('No members', style: TextStyle(color: Colors.white70));
                        }
                        final channel = snapshot.data!;
                        final members = channel.members;
                        
                        if (members.isEmpty) {
                          return const Text('No members yet', style: TextStyle(color: Colors.white70));
                        }
                        
                        return ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.primaries[member.colorIndex % Colors.primaries.length],
                                    child: Text(
                                      member.initial,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          member.role,
                                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
