import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../services/server_service.dart';

class DeleteServerDialog extends StatefulWidget {
  final String serverId;
  final String serverName;
  const DeleteServerDialog({super.key, required this.serverId, required this.serverName});

  @override
  State<DeleteServerDialog> createState() => _DeleteServerDialogState();
}

class _DeleteServerDialogState extends State<DeleteServerDialog> {
  bool _isLoading = false;

  Future<void> _deleteServer() async {
    setState(() => _isLoading = true);
    try {
      await ServerService.instance.deleteServer(widget.serverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server deleted successfully')),
        );
        Navigator.of(context).pop(true);
        // Navigate back to home if needed
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text('Delete Server', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delete "${widget.serverName}"? This cannot be undone.', style: const TextStyle(color: Colors.white)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: _isLoading ? null : _deleteServer,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
