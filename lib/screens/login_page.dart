// Import: flutter/material.dart - Pangunahing Flutter UI widgets
// Import: services/auth_service.dart - Authentication logic (signIn/register)
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Widget: LoginPage
// Gamit: Login screen para sa email/password authentication.
// Connected sa: auth_service.dart (signInWithEmail), main.dart (routing to /home).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// State Class: _LoginPageState
// Gamit: Manage form validation, controllers, loading state para login process.
class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// Function: _signIn
// Gamit: Validate form, tawagin auth service para mag-sign in, navigate to home pag successful.
// Connected sa: auth_service.signInWithEmail, main.dart routes.
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Card(
              color: const Color(0xFF2B2F36),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Row(
                  children: [
                    // Left: Form
                    Expanded(
                      flex: 3,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Column(
                                children: const [
                                  Text('Welcome back!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(height: 6),
                                  Text("We're so excited to see you again!", style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email or Phone Number', filled: true, fillColor: Color(0xFF232328)),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter email or phone';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(labelText: 'Password', filled: true, fillColor: Color(0xFF232328)),
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter password';
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot your password?', style: TextStyle(color: Colors.blue)))),
                            const SizedBox(height: 12),
                            _loading
                                ? const Center(child: CircularProgressIndicator())
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(onPressed: _signIn, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14.0), child: Text('Log In'))),
                                  ),
                            const SizedBox(height: 8),
                            Center(child: TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Need an account? Register', style: TextStyle(color: Colors.white70)))),
                          ],
                        ),
                      ),
                    ),
                    // Right: (removed QR area) keep spacing for balance
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          // Placeholder area (removed QR code per request). You can add illustrations here.
                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
