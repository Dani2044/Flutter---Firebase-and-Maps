import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'welcome.dart';
import 'tracking.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Configuracion del Firebase Messaging: manejar permisos, guardar el token, etc.
    final messaging = FirebaseMessaging.instance;
    messaging.requestPermission();

    // guardar el token cuando este disponible (osea si el usuario ingresa)
    messaging
        .getToken()
        .then((token) async {
          if (authService.currentUser != null) {
            await authService.updateFcmToken(token);
          }
        })
        .catchError((e) {
          // ignorar errores de token
        });

    // manejo de notificacion cuando la app no estaba abierta
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && message.data['trackedUid'] != null) {
        final trackedUid = message.data['trackedUid'];
        if (authService.currentUser != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => TrackingPage(trackedUid: trackedUid),
            ),
          );
        } else {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      final trackedUid = data['trackedUid'];
      if (trackedUid != null) {
        if (authService.currentUser != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => TrackingPage(trackedUid: trackedUid),
            ),
          );
        } else {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
          );
        }
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const WelcomePage();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool? isAvailable;
  LatLng? userPosition;
  GoogleMapController? _mapController;
  Marker? _userMarker; // Cambiar de Set<Marker> a Marker?
  final Set<Marker> _otherMarkers = {}; // Para los otros marcadores
  List<Map<String, dynamic>> availableUsers = [];
  String? imageURL;

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingLocation = false;
  LocationPermission? _locationPermission;
  bool _deniedOnce = false;
  final Map<String, StreamSubscription<DatabaseEvent>>
  _userPositionSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();

    FirebaseMessaging.instance
        .getToken()
        .then((token) {
          final auth = context.read<AuthService>();
          if (auth.currentUser != null && token != null) {
            auth.updateFcmToken(token);
          }
        })
        .catchError((_) {});

    _loadMarkersFromJson();
  }

  /// Calcula la distancia en metros entre dos coordenadas
  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000;
    final dLat = (end.latitude - start.latitude) * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(start.latitude * math.pi / 180) *
            math.cos(end.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _loadUserData() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
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

    // cargar usuarios disponibles
    _loadAvailableUsers();

    if (mounted) {
      _updateMarker();
      setState(() {});
      if (_mapController != null && userPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(userPosition!, 16),
        );
      }
    }
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final ref = FirebaseDatabase.instance.ref('users');
      final currentUser = context.read<AuthService>().currentUser;
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final usersData = snapshot.value as Map<dynamic, dynamic>;
        availableUsers.clear();

        usersData.forEach((uid, userData) {
          // excluir al usuario actual
          if (uid == currentUser?.uid) return;

          if (userData is Map<dynamic, dynamic>) {
            final available = userData['available'] ?? false;
            if (available == true) {
              final distance = userPosition != null
                  ? _calculateDistance(
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

        // Ordenar por distancia
        availableUsers.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          availableUsers = [];
        });
      }
    }
  }

  void _updateMarker() {
    if (userPosition == null) return;

    // Actualizar solo el marcador del usuario
    _userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: userPosition!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: 'Tu ubicación'),
    );
  }

  void _showUserOnMap(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    _userPositionSubscriptions[uid]?.cancel();

    final ref = FirebaseDatabase.instance.ref('users/$uid');
    _userPositionSubscriptions[uid] = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final lat = (data['latitude'] ?? 0.0).toDouble();
      final lng = (data['longitude'] ?? 0.0).toDouble();
      final newPosition = LatLng(lat, lng);

      final markerId = MarkerId(uid);
      _otherMarkers.removeWhere((m) => m.markerId == markerId);
      _otherMarkers.add(
        Marker(
          markerId: markerId,
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title:
                '${data['firstName'] ?? 'Usuario'} ${data['lastName'] ?? ''}',
            snippet:
                'Distancia: ${(userPosition != null ? _calculateDistance(userPosition!, newPosition) / 1000 : 0).toStringAsFixed(2)} km',
          ),
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));

      setState(() {});
    });
  }

  Future<void> _toggleAvailability() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final newValue = !(isAvailable ?? false);
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/available');
    await ref.set(newValue);

    if (mounted) {
      setState(() => isAvailable = newValue);
    }
  }

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(27.34, -122.03),
    zoom: 14.4,
  );

  Future<void> _loadMarkersFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/points.json',
      );

      // Decodificar el JSON y acceder a la lista de ubicaciones
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final List<dynamic> jsonList = jsonMap['locationsArray'];

      for (int i = 0; i < jsonList.length; i++) {
        final markerData = jsonList[i];
        final marker = Marker(
          markerId: MarkerId('json_${markerData['name']}_$i'),
          position: LatLng(
            (markerData['latitude'] as num).toDouble(),
            (markerData['longitude'] as num).toDouble(),
          ),
          infoWindow: InfoWindow(
            title: markerData['name'] as String,
            snippet:
                "Lat: ${markerData['latitude']}, Lng: ${markerData['longitude']}",
          ),
        );
        _otherMarkers.add(marker);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error al cargar los marcadores JSON: $e');
    }
  }

  // Permisos //

  void _startPositionUpdates() {
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
          _updateUserLocation(position);
        });

    setState(() {
      _isTrackingLocation = true;
    });
  }

  Future<void> _updateUserLocation(Position position) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final newPosition = LatLng(position.latitude, position.longitude);

    final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
    await ref.update({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    if (mounted) {
      setState(() {
        userPosition = newPosition;
        _updateMarker();
      });
    }
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    setState(() {
      _isTrackingLocation = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seguimiento de ubicación detenido'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
            Spacer(),
            if (user != null) ...[
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: (imageURL != null && imageURL!.isNotEmpty)
                    ? NetworkImage(imageURL!)
                    : null,
                child: (imageURL == null || imageURL!.isEmpty)
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 18,
                  color: isAvailable == true ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isAvailable == true ? Icons.toggle_on : Icons.toggle_off,
              color: isAvailable == true ? Colors.green : Colors.grey,
              size: 38,
            ),
            onPressed: isAvailable == null ? null : _toggleAvailability,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: userPosition != null
            ? CameraPosition(target: userPosition!, zoom: 14.4)
            : _initialPosition,
        markers: {if (_userMarker != null) _userMarker!, ..._otherMarkers},
        zoomControlsEnabled: false,
        onMapCreated: (controller) {
          _mapController = controller;
          if (userPosition != null) {
            controller.animateCamera(CameraUpdate.newLatLng(userPosition!));
          }
        },
        onTap: (LatLng pos) {
          setState(() {
            _otherMarkers.clear();
          });
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              _showAvailableUsersList(context);
            },
            tooltip: 'Ver usuarios disponibles',
            child: Icon(Icons.people),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () async {
              if (_otherMarkers.isEmpty) {
                await _loadMarkersFromJson();
              } else {
                setState(() {
                  _otherMarkers.removeWhere(
                    (marker) => marker.markerId.value.startsWith('json_'),
                  );
                });
              }
            },
            tooltip: 'Cargar marcadores JSON',
            child: Icon(
              _otherMarkers.isNotEmpty ? Icons.map : Icons.map_outlined,
            ),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _handleLocationButtonPressed,
            tooltip: _isTrackingLocation
                ? 'Detener seguimiento'
                : 'Iniciar seguimiento de ubicación',
            backgroundColor: _isTrackingLocation ? Colors.cyan : null,
            child: Icon(
              _isTrackingLocation ? Icons.location_disabled : Icons.my_location,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    for (var sub in _userPositionSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _handleLocationButtonPressed() async {
    if (_isTrackingLocation) {
      _stopLocationTracking();
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor activa los servicios de ubicación.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _locationPermission = await Geolocator.checkPermission();

      if (_locationPermission == LocationPermission.denied) {
        if (_deniedOnce) {
          bool shouldRequest = await _showPermissionRationaleDialog(context);
          if (!shouldRequest) return;
        }

        _locationPermission = await Geolocator.requestPermission();
        _deniedOnce = true;
      }

      if (_locationPermission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permiso denegado permanentemente. Actívalo desde ajustes.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_locationPermission == LocationPermission.whileInUse ||
          _locationPermission == LocationPermission.always) {
        _startPositionUpdates();

        final currentPosition = await Geolocator.getCurrentPosition();
        _updateUserLocation(currentPosition);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(currentPosition.latitude, currentPosition.longitude),
            18,
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seguimiento de ubicación iniciado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _showPermissionRationaleDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permiso de ubicación requerido'),
            content: const Text(
              'Para mostrar tu posición en el mapa y permitir el seguimiento en tiempo real, '
              'la aplicación necesita acceder a tu ubicación. '
              '¿Deseas conceder el permiso?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAvailableUsersList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Usuarios Disponibles (${availableUsers.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: availableUsers.isEmpty
                    ? const Center(child: Text('No hay usuarios disponibles'))
                    : ListView.builder(
                        itemCount: availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = availableUsers[index];
                          final distance = user['distance'] as double;
                          final distanceKm = distance / 1000;

                          final String firstNameStr =
                              (user['firstName'] ?? '') as String;
                          final String lastNameStr =
                              (user['lastName'] ?? '') as String;
                          final String initials = (() {
                            String s = '';
                            if (firstNameStr.isNotEmpty)
                              s += firstNameStr[0].toUpperCase();
                            if (lastNameStr.isNotEmpty)
                              s += lastNameStr[0].toUpperCase();
                            return s.isEmpty ? 'U' : s;
                          })();

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: (() {
                                final imageUrl = (user['imageUrl'] ?? '') as String;
                                if (imageUrl.isNotEmpty) {
                                  return CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: NetworkImage(imageUrl),
                                  );
                                }
                                return CircleAvatar(child: Text(initials));
                              })(),
                              title: Text(
                                '${user['firstName']} ${user['lastName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] as String),
                                  Text(
                                    'Distancia: ${distanceKm.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () {
                                  _showUserOnMap(user);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.location_on),
                                label: const Text('Ver'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
