import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import 'server_audience_dialog.dart';

class CreateServerDialog extends StatelessWidget {
  final void Function(String)? onCreate;
  const CreateServerDialog({super.key, this.onCreate});

  Widget _templateTile(BuildContext context, IconData icon, String title) {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: () {
          // open audience dialog next
          showDialog(context: context, builder: (_) => ServerAudienceDialog(templateTitle: title, onCreate: onCreate));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = MediaQuery.of(context).size.height * 0.9;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create Your Server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Your server is where you and your friends hang out. Make yours and start talking.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _templateTile(context, Icons.person, 'Create My Own'),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('START FROM A TEMPLATE', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                          _templateTile(context, Icons.videogame_asset, 'Gaming'),
                          _templateTile(context, Icons.people, 'Friends'),
                          _templateTile(context, Icons.school, 'Study Group'),
                          _templateTile(context, Icons.business, 'School Club'),
                          _templateTile(context, Icons.public, 'Local Community'),
                        ],
                      ),
              const SizedBox(height: 8),
              const Center(child: Text('Have an invite already?', style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join server (mock)'))); }, child: const Text('Join a Server')),
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
