import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_data.dart';
import '../services/jeepney_service.dart';

class DashboardScreen extends StatefulWidget {
  final String jeepId;

  const DashboardScreen({super.key, required this.jeepId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final JeepneyService _service = JeepneyService();
  late Stream<JeepneyData> _jeepStream;
  final MapController _mapController = MapController();

  // Passenger alerts
  List<Map<String, dynamic>> _alerts = [];
  late StreamSubscription _alertSubscription;

  @override
  void initState() {
    super.initState();
    _jeepStream = _service.streamJeepneyData(widget.jeepId);
    _service.initializeNotifications();
    _service.startLocationUpdates(widget.jeepId);

    // Subscribe to passenger alerts
    _alertSubscription = _service.streamAlerts(widget.jeepId).listen((alerts) {
      if (mounted) setState(() => _alerts = alerts);
    });
  }

  @override
  void dispose() {
    _alertSubscription.cancel();
    super.dispose();
  }

  // Helper for smooth map movement
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'stop_request':
        return Icons.pan_tool_rounded;
      case 'emergency':
        return Icons.warning_rounded;
      case 'overloading':
        return Icons.groups_rounded;
      default:
        return Icons.notification_important_rounded;
    }
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'stop_request':
        return const Color(0xFFFF9800);
      case 'emergency':
        return const Color(0xFFD32F2F);
      case 'overloading':
        return const Color(0xFF1565C0);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              widget.jeepId.toUpperCase().replaceAll('_', ' '),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<JeepneyData>(
        stream: _jeepStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final isPassengerOverloaded =
              data.passengerCount >= data.maxSeatCapacity;
          final bool weightLimitExceeded =
              data.currentWeight > data.maxWeightCapacity;

          return Column(
            children: [
              // 1. Overload Alert Banners
              if (weightLimitExceeded)
                _buildAlertBanner(
                  "WEIGHT LIMIT EXCEEDED!",
                  Icons.monitor_weight_outlined,
                ),
              if (isPassengerOverloaded)
                _buildAlertBanner(
                  "PASSENGER LIMIT EXCEEDED!",
                  Icons.groups_rounded,
                ),

              // 2. Passenger Alert Banners
              ..._alerts.map((alert) => _buildPassengerAlertBanner(alert)),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Map Card
                        Container(
                          height: MediaQuery.of(context).size.height * 0.35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      data.latitude,
                                      data.longitude,
                                    ),
                                    initialZoom: 16.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            data.latitude,
                                            data.longitude,
                                          ),
                                          width: 80,
                                          height: 80,
                                          child: const Icon(
                                            Icons.directions_bus,
                                            color: Color(0xFF2D6A1E),
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: FloatingActionButton.small(
                                    backgroundColor: Colors.white,
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.black87,
                                    ),
                                    onPressed: () {
                                      _animatedMapMove(
                                        LatLng(data.latitude, data.longitude),
                                        16.0,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: "PASSENGERS",
                                value: "${data.passengerCount}",
                                subValue: "/ ${data.maxSeatCapacity}",
                                icon: Icons.groups_rounded,
                                color: isPassengerOverloaded
                                    ? Colors.red
                                    : const Color(0xFF00C853),
                                isAlert: isPassengerOverloaded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                title: "WEIGHT",
                                value:
                                    data.currentWeight.toStringAsFixed(0),
                                subValue: "kg",
                                icon: Icons.scale_rounded,
                                color: weightLimitExceeded
                                    ? Colors.red
                                    : const Color(0xFF2D6A1E),
                                isAlert: weightLimitExceeded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Vehicle Details
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                Icons.pin_drop_rounded,
                                "Route",
                                data.route,
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                Icons.speed_rounded,
                                "Speed",
                                "${data.speed.toStringAsFixed(1)} km/h",
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                Icons.access_time_rounded,
                                "Last Updated",
                                _formatTimestamp(data.lastUpdated),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Passenger Alert Banner ────────────────────────────────────────────────
  Widget _buildPassengerAlertBanner(Map<String, dynamic> alert) {
    final type = alert['type'] ?? 'unknown';
    final message = alert['message'] ?? 'Alert from passenger';
    final name = alert['passengerName'] ?? 'A passenger';
    final timestamp = alert['timestamp'] as int? ?? 0;
    final alertId = alert['id'] as String;
    final color = _alertColor(type);

    return Container(
      color: color.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Icon(_alertIcon(type), color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "$name • ${_timeAgo(timestamp)}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _service.dismissAlert(widget.jeepId, alertId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAlert ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? color : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[600]),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  Widget _buildAlertBanner(String message, IconData icon) {
    return Container(
      color: Colors.redAccent,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
