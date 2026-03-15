import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import 'passenger/passenger_map_screen.dart';
import 'dashboard_screen.dart';
import 'no_jeepney_assigned_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _handleLogin({bool isGoogle = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = isGoogle
          ? await _authService.signInWithGoogle()
          : await _authService.signInWithEmail(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );

      if (profile != null) {
        _navigateBasedOnRole(profile);
      } else {
        setState(() => _errorMessage = "Sign in was cancelled or failed.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateBasedOnRole(UserProfile profile) {
    if (!mounted) return;
    if (profile.isOperator) {
      if (profile.assignedJeepney != null && profile.assignedJeepney!.isNotEmpty) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DashboardScreen(jeepId: profile.assignedJeepney!)));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => NoJeepneyAssignedScreen(userEmail: profile.email)));
      }
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PassengerMapScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFDFF0D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  // Ensures the column is at least as tall as the visible area
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ── Spacer (top breathing room) ────────────────────
                        const Spacer(),

                        // ── Logo ────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── White card ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.07),
                                  blurRadius: 28,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Sign In to continue",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                // Error banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                _buildField(
                                  controller: _emailController,
                                  label: "Email",
                                  keyboardType: TextInputType.emailAddress,
                                  suffixIcon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _passwordController,
                                  label: "Password",
                                  obscureText: _obscurePassword,
                                  suffixIcon: _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),

                                const SizedBox(height: 24),

                                // Primary button
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : () => _handleLogin(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D6A1E),
                                      foregroundColor: Colors.white,
                                      elevation: 3,
                                      shadowColor: const Color(0xFF2D6A1E).withOpacity(0.35),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2.5),
                                          )
                                        : const Text(
                                            "Sign In",
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade200)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text("OR",
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1)),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade200)),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Google button
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : () => _handleLogin(isGoogle: true),
                                    icon: const Icon(Icons.g_mobiledata,
                                        size: 26, color: Color(0xFF2D6A1E)),
                                    label: const Text(
                                      "Sign in with Google",
                                      style: TextStyle(
                                          color: Color(0xFF2D6A1E),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30)),
                                      side: const BorderSide(color: Color(0xFF2D6A1E), width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Spacer (push link down with consistent padding) ─
                        const Spacer(),

                        // ── Register link — always stays above safe area ────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?  ",
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                                child: const Text(
                                  "Register",
                                  style: TextStyle(
                                    color: Color(0xFF2D6A1E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8EDD3), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          floatingLabelStyle: const TextStyle(color: Color(0xFF2D6A1E), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, color: Colors.grey[400], size: 20),
                )
              : null,
        ),
      ),
    );
  }
}
