import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/jeepney_data.dart';
import '../../models/user_profile.dart';
import '../../services/jeepney_service.dart';
import '../../services/auth_service.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String jeepId;
  const VehicleDetailsScreen({super.key, required this.jeepId});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final JeepneyService _service = JeepneyService();
  final AuthService _authService = AuthService();
  late Stream<JeepneyData> _jeepStream;

  UserProfile? _userProfile;
  DateTime? _lastAlertTime;
  static const _alertCooldown = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _jeepStream = _service.streamJeepneyData(widget.jeepId);
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final profile = await _authService.getUserProfile(uid);
      if (mounted) setState(() => _userProfile = profile);
    }
  }

  bool get _canSendAlert {
    if (_lastAlertTime == null) return true;
    return DateTime.now().difference(_lastAlertTime!) >= _alertCooldown;
  }

  int get _cooldownRemaining {
    if (_lastAlertTime == null) return 0;
    final diff = _alertCooldown - DateTime.now().difference(_lastAlertTime!);
    return diff.inSeconds.clamp(0, 30);
  }

  Future<void> _sendAlert(String type, String message) async {
    if (!_canSendAlert) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please wait $_cooldownRemaining seconds before sending another alert."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _userProfile?.name ?? 'A passenger';

    await _service.sendPassengerAlert(
      jeepId: widget.jeepId,
      type: type,
      message: message,
      passengerName: name,
    );

    setState(() => _lastAlertTime = DateTime.now());

    if (mounted) {
      Navigator.pop(context); // Close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text("Alert sent to operator!"),
            ],
          ),
          backgroundColor: Color(0xFF2D6A1E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAlertSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Alert Operator",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Choose the type of alert to send",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildAlertOption(
              icon: Icons.pan_tool_rounded,
              color: const Color(0xFFFF9800),
              title: "Request Stop",
              subtitle: "Notify operator you need to get off",
              onTap: () => _sendAlert(
                "stop_request",
                "A passenger is requesting a stop",
              ),
            ),
            const SizedBox(height: 12),
            _buildAlertOption(
              icon: Icons.warning_rounded,
              color: const Color(0xFFD32F2F),
              title: "Emergency",
              subtitle: "Report an emergency situation",
              onTap: () => _sendAlert(
                "emergency",
                "A passenger reported an emergency!",
              ),
            ),
            const SizedBox(height: 12),
            _buildAlertOption(
              icon: Icons.groups_rounded,
              color: const Color(0xFF1565C0),
              title: "Overloading Concern",
              subtitle: "Report suspected overloading",
              onTap: () => _sendAlert(
                "overloading",
                "A passenger flagged an overloading concern",
              ),
            ),

            if (!_canSendAlert) ...[
              const SizedBox(height: 16),
              Text(
                "Cooldown: ${_cooldownRemaining}s remaining",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _canSendAlert ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _canSendAlert ? color.withOpacity(0.06) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _canSendAlert ? color.withOpacity(0.15) : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _canSendAlert ? color.withOpacity(0.15) : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _canSendAlert ? color : Colors.grey, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _canSendAlert ? const Color(0xFF1A1A1A) : Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JeepneyData>(
      stream: _jeepStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F4F8),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF2D6A1E))),
          );
        }

        final data = snapshot.data!;
        final isPassengerOverloaded = data.passengerCount >= data.maxSeatCapacity;
        final isWeightOverloaded = data.isOverloaded || data.currentWeight > data.maxWeightCapacity;
        final isSafe = !isPassengerOverloaded && !isWeightOverloaded;
        final seatAvailable = data.maxSeatCapacity - data.passengerCount;
        final loadPercent = (data.currentWeight / data.maxWeightCapacity * 100).clamp(0, 999);

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          body: Column(
            children: [
              // ── Teal Header ──────────────────────────────────────────────
              _buildHeader(context, data, isSafe),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Safety status card
                      _buildSafetyCard(isSafe),
                      const SizedBox(height: 10),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.event_seat_rounded,
                              title: "SEATS",
                              value: "$seatAvailable",
                              sub: "Available",
                              color: isPassengerOverloaded
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF2D6A1E),
                              isAlert: isPassengerOverloaded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.pie_chart_rounded,
                              title: "LOAD",
                              value: "${loadPercent.toStringAsFixed(0)}%",
                              sub: "Capacity",
                              color: isWeightOverloaded
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFFF59E0B),
                              isAlert: isWeightOverloaded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Vehicle status section
                      const Text(
                        "Vehicle Status",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailsCard(data),
                      const SizedBox(height: 12),

                      // Alert Operator button
                      _buildAlertButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, JeepneyData data, bool isSafe) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A1E), Color(0xFF4BA028)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSafe
                          ? Colors.white.withOpacity(0.2)
                          : Colors.redAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSafe ? Icons.gpp_good_rounded : Icons.warning_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSafe ? "Safe" : "Overloaded",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Jeepney info
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.jeepId.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.route_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          data.route,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyCard(bool isSafe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isSafe ? const Color(0xFF2D6A1E) : Colors.redAccent).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isSafe ? Icons.gpp_good_rounded : Icons.warning_amber_rounded,
            size: 40,
            color: isSafe ? const Color(0xFF4BA028) : Colors.redAccent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSafe ? "Safe Capacity" : "Overloaded",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSafe ? const Color(0xFF2D6A1E) : Colors.redAccent,
                  ),
                ),
                Text(
                  isSafe
                      ? "This vehicle is within safe limits."
                      : "This vehicle has exceeded safety limits.",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat card ────────────────────────────────────────────────────────────
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String sub,
    required Color color,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? color : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Details card ─────────────────────────────────────────────────────────
  Widget _buildDetailsCard(JeepneyData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.scale_rounded, "Current Weight", "${data.currentWeight.toStringAsFixed(0)} kg"),
          const Divider(height: 16),
          _buildDetailRow(Icons.monitor_weight_outlined, "Max Weight", "${data.maxWeightCapacity.toStringAsFixed(0)} kg"),
          const Divider(height: 16),
          _buildDetailRow(Icons.speed_rounded, "Speed", "${data.speed.toStringAsFixed(1)} km/h"),
          const Divider(height: 16),
          _buildDetailRow(Icons.access_time_rounded, "Last Updated", _formatTimestamp(data.lastUpdated)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[600]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), fontSize: 14),
        ),
      ],
    );
  }

  // ── Alert Operator Button ────────────────────────────────────────────────
  Widget _buildAlertButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _showAlertSheet,
        icon: const Icon(Icons.notifications_active_rounded, size: 20),
        label: const Text(
          "Alert Operator",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
