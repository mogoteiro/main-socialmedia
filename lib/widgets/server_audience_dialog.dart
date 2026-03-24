import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import 'customize_server_dialog.dart';

class ServerAudienceDialog extends StatelessWidget {
  final String templateTitle;
  final void Function(String)? onCreate;
  const ServerAudienceDialog({super.key, required this.templateTitle, this.onCreate});

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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tell Us More About Your Server', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('In order to help you with your setup, is your new server for just a few friends or a larger community?', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 18),
              Card(
                color: AppColors.cardBackground,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.white),
                  title: const Text('For me and my friends', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    // open customize dialog on top; keep this dialog in stack so Back works
                    showDialog(context: context, builder: (_) => CustomizeServerDialog(templateTitle: templateTitle, audience: 'friends', onCreate: onCreate));
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.cardBackground,
                child: ListTile(
                  leading: const Icon(Icons.public, color: Colors.white),
                  title: const Text('For a club or community', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    showDialog(context: context, builder: (_) => CustomizeServerDialog(templateTitle: templateTitle, audience: 'community', onCreate: onCreate));
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () { Navigator.pop(context); }, child: const Text('Back', style: TextStyle(color: Colors.white70))),
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
