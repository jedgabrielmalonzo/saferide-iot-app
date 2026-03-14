import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/jeepney_service.dart';
import '../../services/auth_service.dart';
import '../../models/jeepney_data.dart';
import '../../models/user_profile.dart';
import '../splash_screen.dart';
import 'vehicle_details_screen.dart';

// Sign-out redirect helper
class _SplashRedirect extends StatelessWidget {
  const _SplashRedirect();
  @override
  Widget build(BuildContext context) => const SplashScreen();
}

// ─────────────────────────────────────────────────────────────────────────────
// Home screen shown to passenger after login
// ─────────────────────────────────────────────────────────────────────────────
class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final JeepneyService _jeepService = JeepneyService();
  final AuthService _authService = AuthService();

  Position? _userPosition;
  UserProfile? _userProfile;
  bool _isLocating = true;
  String? _locationAddress;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _getUserLocation();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final profile = await _authService.getUserProfile(uid);
      if (mounted) setState(() => _userProfile = profile);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLocating = false;
        });
        _reverseGeocode(position.latitude, position.longitude);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String get _firstName {
    final name = _userProfile?.name ?? '';
    return name.split(' ').first.isNotEmpty ? name.split(' ').first : 'Passenger';
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'SafeRideApp/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null && mounted) {
          final parts = <String>[
            if (addr['road'] != null) addr['road'],
            if (addr['suburb'] != null) addr['suburb'],
            if (addr['city'] != null) addr['city']
            else if (addr['town'] != null) addr['town']
            else if (addr['municipality'] != null) addr['municipality'],
          ];
          setState(() {
            _locationAddress = parts.isNotEmpty ? parts.join(', ') : data['display_name'];
          });
        }
      }
    } catch (_) {
      // Silently fall back to coordinates
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          // ── Teal header ──────────────────────────────────────────────────
          _buildHeader(context),

          // ── Scrollable body ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map card
                  _buildMapCard(),
                  const SizedBox(height: 16),

                  // Current location
                  _buildLocationRow(),
                  const SizedBox(height: 20),

                  // Search / nearest bus stop
                  _buildBusStopSearch(context),
                  const SizedBox(height: 20),

                  // Nearby jeepneys section
                  _buildNearbyJeepneys(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A7D6F), Color(0xFF25A896)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative city silhouette
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 70),
                painter: _CitySkylinePainter(),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: avatar + sign out
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: _userProfile?.profilePictureUrl != null
                            ? NetworkImage(_userProfile!.profilePictureUrl!)
                            : null,
                        child: _userProfile?.profilePictureUrl == null
                            ? const Icon(Icons.person, color: Colors.white, size: 22)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
                        onPressed: () async {
                          await _authService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const _SplashRedirect()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${_greeting()}, $_firstName",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Track your nearest SafeRide jeepney.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MAP CARD ───────────────────────────────────────────────────────────────
  Widget _buildMapCard() {
    final lat = _userPosition?.latitude ?? 14.7338;
    final lng = _userPosition?.longitude ?? 121.1249;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _isLocating
            ? Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF25A896)),
                ),
              )
            : FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // static preview
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.saferide.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF25A896).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A7D6F),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // ── CURRENT LOCATION ROW ───────────────────────────────────────────────────
  Widget _buildLocationRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF25A896).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Color(0xFF1A7D6F), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Your current location",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationAddress ?? 
                    (_userPosition != null
                      ? "${_userPosition!.latitude.toStringAsFixed(4)}°N, ${_userPosition!.longitude.toStringAsFixed(4)}°E"
                      : "Location not available"),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH BUS STOP ────────────────────────────────────────────────────────
  Widget _buildBusStopSearch(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerLiveMapScreen(userPosition: _userPosition),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Search for nearest bus stop",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_bus, color: Color(0xFFFF6B35), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Find jeepneys near you",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF25A896)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── NEARBY JEEPNEYS PREVIEW ────────────────────────────────────────────────
  Widget _buildNearbyJeepneys(BuildContext context) {
    return StreamBuilder<List<JeepneyData>>(
      stream: _jeepService.streamAllJeepneys(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final jeeps = snapshot.data!;
        // Sort by distance if we have user position
        List<JeepneyData> sorted = List.from(jeeps);
        if (_userPosition != null) {
          sorted.sort((a, b) {
            double distA = _dist(
              _userPosition!.latitude, _userPosition!.longitude,
              a.latitude, a.longitude,
            );
            double distB = _dist(
              _userPosition!.latitude, _userPosition!.longitude,
              b.latitude, b.longitude,
            );
            return distA.compareTo(distB);
          });
        }

        final nearby = sorted.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Nearby Jeepneys",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PassengerLiveMapScreen(
                          userPosition: _userPosition,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "See all on map",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF25A896),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...nearby.map((jeep) => _buildJeepCard(context, jeep)),
          ],
        );
      },
    );
  }

  Widget _buildJeepCard(BuildContext context, JeepneyData jeep) {
    final distKm = _userPosition != null
        ? _dist(
            _userPosition!.latitude, _userPosition!.longitude,
            jeep.latitude, jeep.longitude,
          )
        : null;

    final distStr = distKm != null
        ? distKm < 1
            ? "${(distKm * 1000).toStringAsFixed(0)} m away"
            : "${distKm.toStringAsFixed(1)} km away"
        : "Distance unknown";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerLiveMapScreen(
              userPosition: _userPosition,
              initialSelectedJeepId: jeep.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: jeep.status == 'Available'
                    ? const Color(0xFF25A896).withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_bus,
                color: jeep.status == 'Available'
                    ? const Color(0xFF1A7D6F)
                    : Colors.orange[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jeep.route,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    distStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: jeep.status == 'Available'
                    ? const Color(0xFF25A896).withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                jeep.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: jeep.status == 'Available'
                      ? const Color(0xFF1A7D6F)
                      : Colors.orange[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;
}

// ─────────────────────────────────────────────────────────────────────────────
// City skyline decorative painter
// ─────────────────────────────────────────────────────────────────────────────
class _CitySkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);

    // Draw each building as a separate rect for simplicity
    final buildings = [
      [10.0, 50.0, 30.0],
      [45.0, 30.0, 25.0],
      [75.0, 45.0, 35.0],
      [115.0, 20.0, 20.0],
      [140.0, 38.0, 28.0],
      [175.0, 55.0, 22.0],
      [200.0, 25.0, 30.0],
      [240.0, 40.0, 25.0],
      [270.0, 50.0, 35.0],
      [315.0, 28.0, 20.0],
      [340.0, 42.0, 30.0],
    ];

    for (final b in buildings) {
      final x = b[0];
      final h = b[1];
      final w = b[2];
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, w, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen live tracking map (opened when user taps search / jeep card)
// ─────────────────────────────────────────────────────────────────────────────
class PassengerLiveMapScreen extends StatefulWidget {
  final Position? userPosition;
  final String? initialSelectedJeepId;

  const PassengerLiveMapScreen({
    super.key,
    this.userPosition,
    this.initialSelectedJeepId,
  });

  @override
  State<PassengerLiveMapScreen> createState() => _PassengerLiveMapScreenState();
}

class _PassengerLiveMapScreenState extends State<PassengerLiveMapScreen> {
  final JeepneyService _service = JeepneyService();
  late Stream<List<JeepneyData>> _jeepsStream;
  final MapController _mapController = MapController();

  String? _selectedJeepId;
  JeepneyData? _selectedJeep;
  Map<String, List<LatLng>> _routes = {};

  @override
  void initState() {
    super.initState();
    _jeepsStream = _service.streamAllJeepneys();
    _selectedJeepId = widget.initialSelectedJeepId;
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routeData = await _service.getAllRoutes();
    if (mounted) {
      setState(() {
        _routes = routeData.map((name, points) => MapEntry(
          name,
          points.map((p) => LatLng(p['lat']!, p['lng']!)).toList(),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          StreamBuilder<List<JeepneyData>>(
            stream: _jeepsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF25A896)));
              }
              final jeeps = snapshot.data!;

              JeepneyData? foundJeep;
              try {
                foundJeep = jeeps.firstWhere((j) => j.id == _selectedJeepId);
              } catch (_) {
                foundJeep = null;
              }
              if (foundJeep != _selectedJeep) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedJeep = foundJeep);
                });
              }

              final userPos = widget.userPosition;
              final centerLat = foundJeep?.latitude ??
                  userPos?.latitude ??
                  (jeeps.isNotEmpty ? jeeps.first.latitude : 14.7338);
              final centerLng = foundJeep?.longitude ??
                  userPos?.longitude ??
                  (jeeps.isNotEmpty ? jeeps.first.longitude : 121.1249);

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLng),
                  initialZoom: 15.0,
                  onTap: (_, __) => setState(() {
                    _selectedJeepId = null;
                    _selectedJeep = null;
                  }),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.saferide.app',
                  ),
                  // Route polylines
                  if (_routes.isNotEmpty)
                    PolylineLayer(
                      polylines: _routes.entries.expand((entry) {
                        return [
                          // White border/outline
                          Polyline(
                            points: entry.value,
                            strokeWidth: 8.0,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          // Teal route line on top
                          Polyline(
                            points: entry.value,
                            strokeWidth: 5.0,
                            color: const Color(0xFF1A7D6F),
                          ),
                        ];
                      }).toList(),
                    ),
                  MarkerLayer(
                    markers: jeeps.map((jeep) {
                      final isSelected = _selectedJeepId == jeep.id;
                      return Marker(
                        point: LatLng(jeep.latitude, jeep.longitude),
                        width: isSelected ? 180 : 140,
                        height: isSelected ? 120 : 100,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedJeepId = jeep.id;
                            _selectedJeep = jeep;
                          }),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1A7D6F)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 6,
                                      color: Colors.black.withValues(alpha: 0.3),
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  jeep.route,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.directions_bus,
                                color: const Color(0xFF1A7D6F),
                                size: isSelected ? 56 : 48,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (widget.userPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            widget.userPosition!.latitude,
                            widget.userPosition!.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),

          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Top label
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  "Tap a jeepney to track it",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ),

          // Bottom details card (when jeep selected)
          if (_selectedJeepId != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _buildDetailsCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Driver is on the way",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                "${(_selectedJeep?.etaSeconds ?? 1200) ~/ 60} min",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A7D6F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _selectedJeep?.route ?? "Loading route...",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Driver details
          FutureBuilder<UserProfile?>(
            future: _service.getOperatorProfile(_selectedJeepId!),
            builder: (context, snapshot) {
              final driver = snapshot.data;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: driver?.profilePictureUrl != null
                            ? NetworkImage(driver!.profilePictureUrl!)
                            : null,
                        child: driver?.profilePictureUrl == null
                            ? const Icon(Icons.person, size: 32, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            size: 16,
                            color: Color(0xFF1A7D6F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      driver?.name ?? "Fetching driver...",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _selectedJeep?.plateNumber ?? "---",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        _selectedJeep?.vehicleModel ?? "Jeepney",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // View full details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VehicleDetailsScreen(jeepId: _selectedJeepId!),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7D6F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "View Full Details",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
