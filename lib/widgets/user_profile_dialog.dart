import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String avatarLabelFromName(String name) {
  if (name.isEmpty) return '';
  if (name.contains('@')) return '';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  final first = parts[0].substring(0, 1);
  final second = parts[1].substring(0, 1);
  return (first + second).toUpperCase();
}

class UserProfileDialog extends StatefulWidget {
  final String userName;
  final String userId;
  final Color userColor;
  final List<PostCard> userServerPosts;
  final int selectedChannelIndex;
  final List<String> channels;
  final bool isFriend;
  final VoidCallback? onAddFriend;
  final VoidCallback? onBlock;
  final bool isPersonal;

  const UserProfileDialog({
    super.key,
    required this.userName,
    required this.userId,
    required this.userColor,
    required this.userServerPosts,
    required this.selectedChannelIndex,
    required this.channels,
    this.isFriend = false,
    this.onAddFriend,
    this.onBlock,
    this.isPersonal = false,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final TextEditingController _messageController = TextEditingController();
  late bool _isFriend;

  @override
  void initState() {
    super.initState();
    _isFriend = widget.isFriend;
  }

  String _computeChatId(String meUid) {
    final a = [meUid, widget.userId];
    a.sort();
    return a.join('_');
  }
  void _showMediaFullscreen(BuildContext context, String mediaUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              Center(
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7289DA),
                        ),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[600],
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load media',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final chatId = _computeChatId(me.uid);
    await FirebaseFirestore.instance.collection('private_chats').doc(chatId).collection('messages').add({
      'sender': me.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    try {
      // create a notification for the recipient
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('notifications').add({
        'type': 'message',
        'from': me.uid,
        'text': text,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: widget.userColor,
                        child: Builder(builder: (_) {
                          final label = avatarLabelFromName(widget.userName);
                          return label.isEmpty
                              ? const Icon(Icons.person, color: Colors.white, size: 28)
                              : Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                        }),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.userServerPosts.length} posts in ${widget.channels[widget.selectedChannelIndex]}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.lightGrey400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                              if (!widget.isPersonal && !_isFriend)
                        TextButton.icon(
                          onPressed: () {
                            widget.onAddFriend?.call();
                            setState(() => _isFriend = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Friend request sent to ${widget.userName}')),
                            );
                          },
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: const Text('Add Friend', style: TextStyle(color: Colors.white)),
                        ),
                      if (!widget.isPersonal && _isFriend)
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Confirm Block'),
                                content: Text('Block ${widget.userName}? This will remove them from your friends.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (!mounted) return;
                              widget.onBlock?.call();
                              setState(() => _isFriend = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${widget.userName} blocked')),
                              );
                            }
                          },
                          icon: const Icon(Icons.block, color: Colors.white),
                          label: const Text('Block', style: TextStyle(color: Colors.white)),
                        ),
                              if (widget.isPersonal) ...[
                                IconButton(
                                  icon: const Icon(Icons.settings),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => EditProfileDialog(
                                      initialDisplayName: widget.userName,
                                      initialUserName: widget.userName.toLowerCase().replaceAll(' ', ''),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout),
                                  tooltip: 'Log out',
                                  onPressed: () async {
                                    try {
                                      await AuthService.instance.signOut();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
                                    }
                                  },
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                                iconSize: 24,
                              ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: widget.isPersonal ? 1 : 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppColors.accentBlurple,
                      unselectedLabelColor: AppColors.lightGrey400,
                      indicatorColor: AppColors.accentBlurple,
                      tabs: widget.isPersonal
                          ? [const Tab(text: 'Posts')]
                          : [const Tab(text: 'Posts'), const Tab(text: 'Chat')],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Posts Tab
                          widget.userServerPosts.isEmpty
                              ? Center(
                                  child: Text(
                                    'No posts in this channel',
                                    style: TextStyle(
                                      color: AppColors.lightGrey400,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: widget.userServerPosts.length,
                                  itemBuilder: (context, index) {
                                    final post = widget.userServerPosts[index];
                                    return Card(
                                      color: AppColors.cardBackground,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              post.timestamp,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.lightGrey400,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              post.content,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.5,
                                              ),
                                            ),
                                            if (post.description.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[900],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  post.description,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color:
                                                        AppColors.lightGrey400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (post.gifUrl != null ||
                                                post.imageUrl != null) ...[
                                              const SizedBox(height: 8),
                                              InkWell(
                                                onTap: () {
                                                  _showMediaFullscreen(
                                                    context,
                                                    post.gifUrl ??
                                                        post.imageUrl!,
                                                  );
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 180,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    color: Colors.black,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    child: Stack(
                                                      children: [
                                                        Image.network(
                                                          post.gifUrl ??
                                                              post.imageUrl!,
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                          loadingBuilder:
                                                              (context, child,
                                                                  loadingProgress) {
                                                            if (loadingProgress ==
                                                                null) {
                                                              return child;
                                                            }
                                                            return Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                        Color>(
                                                                  AppColors
                                                                      .accentBlurple,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          errorBuilder:
                                                              (context, error,
                                                                  stackTrace) {
                                                            return Container(
                                                              color: Colors
                                                                  .grey[800],
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  color: AppColors
                                                                      .lightGrey400,
                                                                  size: 32,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        Positioned(
                                                          bottom: 4,
                                                          right: 4,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.black
                                                                  // ignore: deprecated_member_use
                                                                  .withOpacity(
                                                                      0.7),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Icon(
                                                              Icons.fullscreen,
                                                              color:
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          if (!widget.isPersonal)
                            // Chat Tab (real conversations)
                            Column(
                              children: [
                                Expanded(
                                  child: Builder(builder: (context) {
                                    final me = FirebaseAuth.instance.currentUser;
                                    if (me == null) return const Center(child: Text('Sign in to chat', style: TextStyle(color: Colors.white70)));
                                    final chatId = _computeChatId(me.uid);
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('private_chats')
                                          .doc(chatId)
                                          .collection('messages')
                                          .orderBy('createdAt')
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                        final msgs = snap.data!.docs;
                                        return ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: msgs.length,
                                          itemBuilder: (context, index) {
                                            final m = msgs[index].data() as Map<String, dynamic>;
                                            final sender = m['sender'] as String? ?? '';
                                            final text = m['text'] as String? ?? '';
                                            final isMe = FirebaseAuth.instance.currentUser?.uid == sender;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12.0),
                                              child: Row(
                                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.35),
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: isMe ? AppColors.accentBlurple : Colors.grey[700],
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  }),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    border: Border(
                                      top: BorderSide(color: Colors.grey[700]!),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Type a message...',
                                            hintStyle: TextStyle(color: Colors.grey[500]),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(24),
                                              borderSide: BorderSide(color: Colors.grey[700]!),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(24),
                                              borderSide: BorderSide(color: Colors.grey[700]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(24),
                                              borderSide: BorderSide(color: AppColors.accentBlurple),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.accentBlurple,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.send, color: Colors.white),
                                          onPressed: _sendMessage,
                                          iconSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class EditProfileDialog extends StatefulWidget {
  final String initialDisplayName;
  final String initialUserName;

  const EditProfileDialog({super.key, required this.initialDisplayName, required this.initialUserName});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _userNameController;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _loading = false;
  bool _emailHidden = true;
  final FocusNode _displayFocus = FocusNode();
  final FocusNode _userFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Per requirement: leave display name and username blank and ready to edit
    _displayNameController = TextEditingController(text: '');
    _userNameController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _userNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _displayFocus.dispose();
    _userFocus.dispose();
    super.dispose();
  }

  String _maskedEmail() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return '';
    if (!_emailHidden) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts.length > 1 ? '@${parts[1]}' : '';
    if (name.length <= 2) return '*' * name.length + domain;
    final visible = name.substring(0, 1) + '*' * (name.length - 2) + name.substring(name.length - 1);
    return '$visible$domain';
  }

  void _toggleEmailReveal() {
    setState(() => _emailHidden = !_emailHidden);
  }

  void _focusField(TextEditingController controller) {
    if (controller == _displayNameController) {
      FocusScope.of(context).requestFocus(_displayFocus);
    } else {
      FocusScope.of(context).requestFocus(_userFocus);
    }
  }

  Future<void> _save() async {
    // No strict validation required; update only non-empty fields
    setState(() => _loading = true);
    try {
      final display = _displayNameController.text.trim();
      final nick = _userNameController.text.trim();
      if (display.isNotEmpty) await AuthService.instance.updateDisplayName(display);
      if (nick.isNotEmpty) await AuthService.instance.updateUsername(nick);
      if (_newPasswordController.text.isNotEmpty) {
        await AuthService.instance.changePassword(_currentPasswordController.text, _newPasswordController.text);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top cover
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.accentBlurple,
                    child: Builder(builder: (_) {
                      final name = FirebaseAuth.instance.currentUser?.displayName ?? '';
                      final label = avatarLabelFromName(name);
                      return label.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : Text(label, style: const TextStyle(color: Colors.white));
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit User Profile', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Row(children: [const Icon(Icons.tag, size: 16), const SizedBox(width: 6), Text(widget.initialUserName, style: const TextStyle(fontSize: 12))]),
                      ],
                    ),
                  ),
                  ElevatedButton(onPressed: null, child: const Text('Edit User Profile')),
                ],
              ),
              const SizedBox(height: 12),
              // Fields area
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(child: Text(_maskedEmail(), style: const TextStyle(fontSize: 14))),
                                      TextButton(onPressed: _toggleEmailReveal, child: Text(_emailHidden ? 'Reveal' : 'Hide')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Display name
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Display Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _displayNameController, focusNode: _displayFocus, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Display name')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () => _focusField(_displayNameController), child: const Text('Edit')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Username
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Username', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _userNameController, focusNode: _userFocus, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Username')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () => _focusField(_userNameController), child: const Text('Edit')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Passwords
                        TextFormField(controller: _currentPasswordController, decoration: const InputDecoration(labelText: 'Current password'), obscureText: true),
                        const SizedBox(height: 8),
                        TextFormField(controller: _newPasswordController, decoration: const InputDecoration(labelText: 'New password'), obscureText: true),
                        const SizedBox(height: 12),
                        // Blocked users section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blocked Users', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: Card(
                                  color: Colors.grey[900],
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(FirebaseAuth.instance.currentUser?.uid)
                                          .collection('blocked')
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (snap.hasError) return const Text('Failed to load blocked users', style: TextStyle(color: Colors.white70));
                                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                        final docs = snap.data!.docs;
                                        if (docs.isEmpty) return const Text('No blocked users', style: TextStyle(color: Colors.white70));
                                        return ListView.builder(
                                          itemCount: docs.length,
                                          itemBuilder: (context, i) {
                                            final b = docs[i];
                                            final blockedUid = b.id;
                                            return FutureBuilder<DocumentSnapshot>(
                                              future: FirebaseFirestore.instance.collection('users').doc(blockedUid).get(),
                                              builder: (context, userSnap) {
                                                String name = blockedUid;
                                                if (userSnap.hasData && userSnap.data!.exists) {
                                                  final data = userSnap.data!.data() as Map<String, dynamic>;
                                                  name = data['displayName'] as String? ?? data['username'] as String? ?? blockedUid;
                                                }
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(name, style: const TextStyle(color: Colors.white)),
                                                  trailing: TextButton(
                                                    onPressed: () async {
                                                      try {
                                                        await FirebaseFirestore.instance
                                                            .collection('users')
                                                            .doc(FirebaseAuth.instance.currentUser?.uid)
                                                            .collection('blocked')
                                                            .doc(blockedUid)
                                                            .delete();
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unblocked $name')));
                                                      } catch (e) {
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unblock: $e')));
                                                      }
                                                    },
                                                    child: const Text('Unblock'),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), const SizedBox(width: 8), ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator() : const Text('Save'))]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
