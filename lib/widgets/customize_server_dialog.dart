import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import '../screens/server_screen.dart';
import '../../services/server_service.dart';

class CustomizeServerDialog extends StatefulWidget {
  final String templateTitle;
  final String audience;
  final void Function(String)? onCreate;
  const CustomizeServerDialog({super.key, required this.templateTitle, required this.audience, this.onCreate});

  @override
  State<CustomizeServerDialog> createState() => _CustomizeServerDialogState();
}

class _CustomizeServerDialogState extends State<CustomizeServerDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedLogoUrl;
  List<String> _logoUrls = [];
  bool _loadingLogos = false;
  String? _logoError;
  final Set<String> _invalidLogoUrls = {};
  static List<String>? _cachedLogoUrls;

  @override
  void initState() {
    super.initState();
    _nameController.text = '${widget.templateTitle} Server';
    _loadServerLogos();
  }
  Future<void> _loadServerLogos() async {
    if (_loadingLogos) return;
    setState(() => _loadingLogos = true);
    _logoError = null;

    // Show cached immediately if available
    if (_cachedLogoUrls != null && _cachedLogoUrls!.isNotEmpty) {
      if (mounted) setState(() => _logoUrls = List<String>.from(_cachedLogoUrls!));
    }

    final List<String> urls = [];

    Future<List<String>> fetchStorageUrls(List<String> paths) async {
      final storage = FirebaseStorage.instance;
      final List<Reference> items = [];
      for (final path in paths) {
        try {
          final storageRef = storage.ref().child(path);
          final ListResult result = await storageRef.listAll().timeout(const Duration(seconds: 8));
          items.addAll(result.items);
        } catch (e) {
          debugPrint('No items or error listing storage path "$path": $e');
        }
      }

      final List<String> found = [];
      const int concurrency = 6;
      for (int i = 0; i < items.length; i += concurrency) {
        final chunk = items.skip(i).take(concurrency).map((it) async {
          try {
            return await it.getDownloadURL().timeout(const Duration(seconds: 6));
          } catch (e) {
            debugPrint('Failed fetching url for ${it.fullPath}: $e');
            return null;
          }
        }).toList();

        final results = await Future.wait(chunk);
        for (final u in results) {
          if (u != null && !found.contains(u)) found.add(u);
        }
      }
      return found;
    }

    try {
      final storageFuture = fetchStorageUrls(['server', 'server_logos']);
      final firestoreFuture = () async {
        final List<String> found = [];
        try {
          final snap = await FirebaseFirestore.instance.collection('server').get().timeout(const Duration(seconds: 6));
          for (final doc in snap.docs) {
            final data = doc.data();
            const possibleFields = ['img', 'image', 'logoUrl', 'logo_url', 'url'];
            for (final f in possibleFields) {
              if (data.containsKey(f)) {
                final val = data[f];
                if (val is String && val.isNotEmpty && !found.contains(val)) found.add(val);
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching Firestore logos: $e');
        }
        return found;
      }();

      final results = await Future.wait([storageFuture, firestoreFuture]);
      for (final list in results) {
        for (final u in list) {
          if (!urls.contains(u)) urls.add(u);
        }
      }

      _cachedLogoUrls = List<String>.from(urls);
    } catch (e, st) {
      debugPrint('Unexpected error loading logos: $e\n$st');
      _logoError ??= 'Unexpected error loading images';
    } finally {
      if (mounted) {
        setState(() {
          _logoUrls = urls;
          _loadingLogos = false;
        });
      }
    }
  }

  void _showLogoPicker() {
    if (_logoUrls.isEmpty && !_loadingLogos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logos available. Please upload logos to Firebase Storage first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose a Logo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (_loadingLogos)
                Column(
                  children: [
                    const Center(child: CircularProgressIndicator()),
                    if (_logoError != null) ...[
                      const SizedBox(height: 12),
                      Text(_logoError!, style: const TextStyle(color: Colors.redAccent)),
                    ]
                  ],
                )
              else if (_logoUrls.isEmpty)
                Column(
                  children: [
                    if (_logoError != null)
                      Text(_logoError!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    const Text('No logos found. Upload images to Firebase Storage in a folder named "server" or "server_logos".' , style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loadServerLogos, child: const Text('Refresh', style: TextStyle(color: Colors.blue))),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _logoUrls.where((u) => !_invalidLogoUrls.contains(u)).map((url) {
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedLogoUrl = url);
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, _) => Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                            errorWidget: (context, _, _) {
                              if (mounted && !_invalidLogoUrls.contains(url)) {
                                setState(() => _invalidLogoUrls.add(url));
                              }
                              return Container(
                                color: Colors.grey[850],
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              if (!_loadingLogos && _logoUrls.isNotEmpty)
                TextButton(onPressed: _loadServerLogos, child: const Text('Refresh', style: TextStyle(color: Colors.blue))),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createServer() async {
    final name = _nameController.text.trim();
    final serverName = name.isEmpty ? widget.templateTitle : name;
    
    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a server')),
      );
      return;
    }

    try {
      // Save server to Firestore
      final serverId = await ServerService.instance.createServer(serverName, widget.templateTitle, logoUrl: _selectedLogoUrl);

      // After creating the server: notify caller, close dialog and navigate to ServerScreen.
      if (mounted) {
        if (widget.onCreate != null) {
          widget.onCreate!(serverName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created "$serverName" (${widget.audience})')),
          );
        }

        // Pop all routes back to the app root (home) so the create flow isn't visible
        // when the user later presses Back. Then push the ServerScreen on top.
        Future.microtask(() {
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ServerScreen(serverId: serverId, serverName: serverName, logoUrl: _selectedLogoUrl, showQuickStart: false),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating server: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = MediaQuery.of(context).size.height * 0.8;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customize Your Server', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Give your new server a personality with a name and an icon. You can always change it later.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Center(
                child: InkWell(
                  onTap: _showLogoPicker,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(color: Colors.white24),
                      image: _selectedLogoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_selectedLogoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedLogoUrl == null
                        ? const Center(child: Icon(Icons.camera_alt, color: Colors.white24))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _showLogoPicker,
                  child: Text(_selectedLogoUrl == null ? 'Choose an icon' : 'Change icon', style: const TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Server Name *', filled: true, fillColor: Color(0xFF232328))),
              const SizedBox(height: 8),
              Row(children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back', style: TextStyle(color: Colors.white70))), const Spacer(), ElevatedButton(onPressed: _createServer, child: const Text('Create'))]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
