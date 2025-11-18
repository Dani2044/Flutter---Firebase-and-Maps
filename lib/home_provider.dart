import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class HomeProvider extends ChangeNotifier {
  bool? isAvailable;
  LatLng? userPosition;
  Marker? userMarker;
  final Set<Marker> otherMarkers = {};
  List<Map<String, dynamic>> availableUsers = [];
  String? imageURL;

  StreamSubscription<Position>? _positionStreamSubscription;
  bool isTrackingLocation = false;
  LocationPermission? locationPermission;
  bool deniedOnce = false;
  final Map<String, StreamSubscription<DatabaseEvent>> userPositionSubscriptions = {};

  /// Calcula la distancia en metros entre dos coordenadas
  double calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000;
    final dLat = (end.latitude - start.latitude) * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(start.latitude * math.pi / 180) *
            math.cos(end.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> loadUserData(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      isAvailable = (data['available'] ?? false) as bool;
      final lat = (data['latitude'] ?? 4.627561).toDouble();
      final lng = (data['longitude'] ?? -74.064279).toDouble();
      userPosition = LatLng(lat, lng);
      imageURL = (data['imageUrl'] ?? '') as String?;
    } else {
      isAvailable = false;
      userPosition = const LatLng(4.627561, -74.064279);
      await ref.set({
        'available': false,
        'latitude': userPosition!.latitude,
        'longitude': userPosition!.longitude,
      });
    }

    await loadAvailableUsers();
    updateMarker();
    notifyListeners();
  }

  Future<void> loadAvailableUsers() async {
    try {
      final ref = FirebaseDatabase.instance.ref('users');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final usersData = snapshot.value as Map<dynamic, dynamic>;
        availableUsers.clear();

        usersData.forEach((uid, userData) {
          if (userData is Map<dynamic, dynamic>) {
            final available = userData['available'] ?? false;
            if (available == true) {
              final distance = userPosition != null
                  ? calculateDistance(
                      userPosition!,
                      LatLng(
                        (userData['latitude'] ?? 0.0).toDouble(),
                        (userData['longitude'] ?? 0.0).toDouble(),
                      ),
                    )
                  : 0.0;

              availableUsers.add({
                'uid': uid,
                'firstName': userData['firstName'] ?? 'Usuario',
                'lastName': userData['lastName'] ?? '',
                'email': userData['email'] ?? '',
                'imageUrl': userData['imageUrl'] ?? '',
                'latitude': (userData['latitude'] ?? 0.0).toDouble(),
                'longitude': (userData['longitude'] ?? 0.0).toDouble(),
                'distance': distance,
              });
            }
          }
        });

        availableUsers.sort(
          (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
        );
      }
    } catch (e) {
      availableUsers = [];
    }
    notifyListeners();
  }

  void updateMarker() {
    if (userPosition == null) return;

    userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: userPosition!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
    notifyListeners();
  }

  void showUserOnMap(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    userPositionSubscriptions[uid]?.cancel();

    final ref = FirebaseDatabase.instance.ref('users/$uid');
    userPositionSubscriptions[uid] = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final lat = (data['latitude'] ?? 0.0).toDouble();
      final lng = (data['longitude'] ?? 0.0).toDouble();
      final newPosition = LatLng(lat, lng);

      final markerId = MarkerId(uid);
      otherMarkers.removeWhere((m) => m.markerId == markerId);
      otherMarkers.add(
        Marker(
          markerId: markerId,
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '${data['firstName'] ?? 'Usuario'} ${data['lastName'] ?? ''}',
            snippet: 'Distancia: ${(userPosition != null ? calculateDistance(userPosition!, newPosition) / 1000 : 0).toStringAsFixed(2)} km',
          ),
        ),
      );

      notifyListeners();
    });
  }

  Future<void> toggleAvailability(String uid) async {
    final newValue = !(isAvailable ?? false);
    final ref = FirebaseDatabase.instance.ref('users/$uid/available');
    await ref.set(newValue);

    isAvailable = newValue;
    notifyListeners();
  }

  void startPositionUpdates(String uid) {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Stream.periodic(const Duration(seconds: 5))
        .asyncMap(
          (_) => Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ),
        )
        .listen((Position position) {
          updateUserLocation(position, uid);
        });

    isTrackingLocation = true;
    notifyListeners();
  }

  Future<void> updateUserLocation(Position position, String uid) async {
    final newPosition = LatLng(position.latitude, position.longitude);

    final ref = FirebaseDatabase.instance.ref('users/$uid');
    await ref.update({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    userPosition = newPosition;
    updateMarker();
    notifyListeners();
  }

  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    isTrackingLocation = false;
    notifyListeners();
  }

  void clearOtherMarkers() {
    otherMarkers.clear();
    notifyListeners();
  }

  void removeJsonMarkers() {
    otherMarkers.removeWhere(
      (marker) => marker.markerId.value.startsWith('json_'),
    );
    notifyListeners();
  }

  void addJsonMarkers(List<Marker> markers) {
    otherMarkers.addAll(markers);
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    for (var sub in userPositionSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
