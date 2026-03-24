// Import: flutter/material.dart - Pangunahing Flutter UI widgets
// Import: services/auth_service.dart - Authentication logic (registerWithEmail)
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Widget: RegisterPage
// Gamit: Registration screen na may email, name, username, password, DOB.
// Connected sa: auth_service.dart (registerWithEmail), login_page.dart (back navigation).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

// State Class: _RegisterPageState
// Gamit: Manage form fields, DOB dropdowns, validation, loading para registration.
class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _month;
  String? _day;
  String? _year;
  bool _subscribe = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// Function: _createAccount
// Gamit: Validate form & DOB, tawagin auth service para mag-register, navigate to home.
// Connected sa: auth_service.registerWithEmail.
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_month == null || _day == null || _year == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select your date of birth')));
      return;
    }
    setState(() => _loading = true);
    try {
      final display = _displayNameController.text.trim();
      final nick = _userNameController.text.trim();
      final dateOfBirth = '$_month/$_day/$_year';
      await AuthService.instance.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        displayName: display.isEmpty ? null : display,
        username: nick.isEmpty ? null : nick,
        dateOfBirth: dateOfBirth,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DropdownMenuItem<String>> _months() => List.generate(12, (i) => DropdownMenuItem(value: '${i + 1}', child: Text('${i + 1}')));
  List<DropdownMenuItem<String>> _days() => List.generate(31, (i) => DropdownMenuItem(value: '${i + 1}', child: Text('${i + 1}')));
  List<DropdownMenuItem<String>> _years() => List.generate(100, (i) => DropdownMenuItem(value: '${DateTime.now().year - i}', child: Text('${DateTime.now().year - i}')));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: const Color(0xFF2B2F36),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Text('Create an account', style: Theme.of(context).textTheme.titleMedium)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email *', filled: true, fillColor: Color(0xFF232328)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email required';
                          if (!v.contains('@')) return 'Enter valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display Name', filled: true, fillColor: Color(0xFF232328))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _userNameController,
                        decoration: const InputDecoration(labelText: 'Username *', filled: true, fillColor: Color(0xFF232328)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Username required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password *', filled: true, fillColor: Color(0xFF232328)),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password required';
                          if (v.length < 6) return 'Password too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Date of Birth *', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: DropdownButtonFormField<String>(value: _month, items: _months(), onChanged: (v) => setState(() => _month = v), decoration: const InputDecoration(filled: true, fillColor: Color(0xFF232328)))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: _day, items: _days(), onChanged: (v) => setState(() => _day = v), decoration: const InputDecoration(filled: true, fillColor: Color(0xFF232328)))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: _year, items: _years(), onChanged: (v) => setState(() => _year = v), decoration: const InputDecoration(filled: true, fillColor: Color(0xFF232328)))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Checkbox(value: _subscribe, onChanged: (v) => setState(() => _subscribe = v ?? true)),
                        const Expanded(child: Text("(Optional) It's okay to send me emails with updates, tips, and special offers.", style: TextStyle(color: Colors.white70))),
                      ]),
                      const SizedBox(height: 12),
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _createAccount, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14.0), child: Text('Create Account')))),
                      const SizedBox(height: 8),
                      Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Log in', style: TextStyle(color: Colors.white70)))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
