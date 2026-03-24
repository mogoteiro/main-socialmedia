import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../services/channel_service.dart';

class RenameChannelDialog extends StatefulWidget {
  final String channelId;
  final String currentName;

  const RenameChannelDialog({
    super.key,
    required this.channelId,
    required this.currentName,
  });

  @override
  State<RenameChannelDialog> createState() => _RenameChannelDialogState();
}

class _RenameChannelDialogState extends State<RenameChannelDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
  }

  Future<void> _renameChannel() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.currentName) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ChannelService.instance.updateChannelName(widget.channelId, newName);
      if (mounted) Navigator.of(context).pop(newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming channel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rename Channel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Channel Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF232328),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _renameChannel,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Rename'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
