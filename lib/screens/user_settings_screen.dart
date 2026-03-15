import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  final UserProfile? userProfile;
  const UserSettingsScreen({super.key, this.userProfile});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final AuthService _authService = AuthService();

  // Toggles
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _nearbyAlertsEnabled = true;
  bool _crowdAlertEnabled = false;
  bool _darkMapEnabled = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.userProfile;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ────────────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: const Color(0xFF2D6A1E),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2D6A1E), Color(0xFF4BA028)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          // Avatar
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: ClipOval(
                              child: profile?.profilePictureUrl != null
                                  ? Image.network(profile!.profilePictureUrl!, fit: BoxFit.cover)
                                  : const Icon(Icons.person, color: Colors.white, size: 36),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile?.name ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Notifications ──────────────────────────────────────────
                      _sectionHeader("Notifications"),
                      const SizedBox(height: 10),
                      _settingsCard([
                        _toggleTile(
                          icon: Icons.notifications_active_outlined,
                          iconColor: const Color(0xFF2D6A1E),
                          title: "Push Notifications",
                          subtitle: "Get alerts about your tracked jeepneys",
                          value: _notificationsEnabled,
                          onChanged: (v) => setState(() => _notificationsEnabled = v),
                        ),
                        _divider(),
                        _toggleTile(
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          title: "Crowd Alerts",
                          subtitle: "Notify when a jeepney is almost full",
                          value: _crowdAlertEnabled,
                          onChanged: (v) => setState(() => _crowdAlertEnabled = v),
                        ),
                        _divider(),
                        _toggleTile(
                          icon: Icons.near_me,
                          iconColor: const Color(0xFF4BA028),
                          title: "Nearby Jeepney Alerts",
                          subtitle: "Alert when a jeepney is within 200m",
                          value: _nearbyAlertsEnabled,
                          onChanged: (v) => setState(() => _nearbyAlertsEnabled = v),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── Location ──────────────────────────────────────────────
                      _sectionHeader("Location"),
                      const SizedBox(height: 10),
                      _settingsCard([
                        _toggleTile(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFF2D6A1E),
                          title: "Share My Location",
                          subtitle: "Used for distance and ETA calculations",
                          value: _locationEnabled,
                          onChanged: (v) => setState(() => _locationEnabled = v),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── Display ────────────────────────────────────────────────
                      _sectionHeader("Display"),
                      const SizedBox(height: 10),
                      _settingsCard([
                        _toggleTile(
                          icon: Icons.map_outlined,
                          iconColor: const Color(0xFF2D6A1E),
                          title: "Dark Map Style",
                          subtitle: "Use a darker map tile for better contrast",
                          value: _darkMapEnabled,
                          onChanged: (v) => setState(() => _darkMapEnabled = v),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── Account ───────────────────────────────────────────────
                      _sectionHeader("Account"),
                      const SizedBox(height: 10),
                      _settingsCard([
                        _actionTile(
                          icon: Icons.info_outline,
                          iconColor: const Color(0xFF4BA028),
                          title: "App Version",
                          trailing: const Text(
                            "v1.0.0",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                        _divider(),
                        _actionTile(
                          icon: Icons.logout_rounded,
                          iconColor: Colors.redAccent,
                          title: "Sign Out",
                          titleColor: Colors.redAccent,
                          onTap: () => _confirmLogout(context),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Loading overlay ──────────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2D6A1E)),
                        SizedBox(height: 16),
                        Text(
                          "Signing out…",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D6A1E),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2D6A1E),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: titleColor ?? const Color(0xFF1A1A1A),
                ),
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      endIndent: 18,
      color: Colors.grey.shade100,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text("Sign Out",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to sign out?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text("Cancel",
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                      Navigator.pop(dialogCtx);
                        if (mounted) setState(() => _isLoading = true);
                        try {
                          await _authService
                              .signOut()
                              .timeout(const Duration(seconds: 5));
                        } catch (_) {}
                        if (mounted) setState(() => _isLoading = false);
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Sign Out",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
