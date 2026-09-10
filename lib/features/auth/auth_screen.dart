import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _loading = false;
  bool _googleLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Merci de remplir email et mot de passe.');
      return;
    }
    if (_isSignUp && name.isEmpty) {
      _showError('Merci d\'indiquer votre nom.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await SupabaseService.signUp(email: email, password: password, fullName: name);
      } else {
        await SupabaseService.signIn(email: email, password: password);
      }
    } catch (e) {
      if (mounted) _showError('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
    } catch (e) {
      if (mounted) _showError('Connexion Google : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.flight_takeoff, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Envol',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSignUp ? 'Créer un compte voyageur' : 'Connecte-toi pour continuer',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 28),

                      OutlinedButton.icon(
                        onPressed: _googleLoading ? null : _submitGoogle,
                        icon: _googleLoading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 18,
                                width: 18,
                                errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 18),
                              ),
                        label: const Text('Continuer avec Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                          foregroundColor: AppColors.textDark,
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.1))),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('ou', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.1))),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_isSignUp) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 22),

                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isSignUp ? 'Créer mon compte' : 'Se connecter'),
                      ),
                      const SizedBox(height: 14),

                      TextButton(
                        onPressed: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp ? 'Déjà un compte ? Se connecter' : 'Pas encore de compte ? En créer un',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
