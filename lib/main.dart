import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'welcome.dart';
import 'home_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => HomeProvider()),
      ],
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
    // Configuracion del Firebase Messaging
    final messaging = FirebaseMessaging.instance;
    messaging.requestPermission();

    messaging
        .getToken()
        .then((token) async {
          if (authService.currentUser != null) {
            await authService.updateFcmToken(token);
          }
        })
        .catchError((e) {});

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(27.34, -122.03),
    zoom: 14.4,
  );

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, HomeProvider>(
      builder: (context, authService, homeProvider, _) {
        final user = authService.currentUser;

        if (homeProvider.userPosition == null && user != null) {
          Future.microtask(() {
            homeProvider.loadUserData(user.uid);
            _loadMarkersFromJson(context, homeProvider);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (user != null) ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (homeProvider.imageURL != null && homeProvider.imageURL!.isNotEmpty)
                        ? NetworkImage(homeProvider.imageURL!)
                        : null,
                    child: (homeProvider.imageURL == null || homeProvider.imageURL!.isEmpty)
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      color: homeProvider.isAvailable == true ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  homeProvider.isAvailable == true ? Icons.toggle_on : Icons.toggle_off,
                  color: homeProvider.isAvailable == true ? Colors.green : Colors.grey,
                  size: 38,
                ),
                onPressed: homeProvider.isAvailable == null
                    ? null
                    : () => homeProvider.toggleAvailability(user!.uid),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
                onPressed: () async => await authService.signOut(),
              ),
            ],
          ),
          body: GoogleMap(
            initialCameraPosition: homeProvider.userPosition != null
                ? CameraPosition(target: homeProvider.userPosition!, zoom: 14.4)
                : _initialPosition,
            markers: {
              if (homeProvider.userMarker != null) homeProvider.userMarker!,
              ...homeProvider.otherMarkers
            },
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              
              homeProvider.setMapController(controller);
              if (homeProvider.userPosition != null) {
                controller.animateCamera(CameraUpdate.newLatLng(homeProvider.userPosition!));
              }
            },
            onTap: (LatLng pos) {
              homeProvider.clearOtherMarkers();
            },
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: () => _showAvailableUsersList(context, homeProvider),
                tooltip: 'Ver usuarios disponibles',
                child: const Icon(Icons.people),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () async {
                  if (homeProvider.otherMarkers.isEmpty) {
                    await _loadMarkersFromJson(context, homeProvider);
                  } else {
                    homeProvider.removeJsonMarkers();
                  }
                },
                tooltip: 'Cargar marcadores JSON',
                child: Icon(
                  homeProvider.otherMarkers.isNotEmpty ? Icons.map : Icons.map_outlined,
                ),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () async {
                  if (user != null) {
                    await _handleLocationButtonPressed(context, homeProvider, user.uid);
                  }
                },
                tooltip: homeProvider.isTrackingLocation
                    ? 'Detener seguimiento'
                    : 'Iniciar seguimiento de ubicación',
                backgroundColor: homeProvider.isTrackingLocation ? Colors.cyan : null,
                child: Icon(
                  homeProvider.isTrackingLocation ? Icons.location_disabled : Icons.my_location,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadMarkersFromJson(BuildContext context, HomeProvider homeProvider) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/points.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final List<dynamic> jsonList = jsonMap['locationsArray'];

      final List<Marker> markers = [];
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
            snippet: "Lat: ${markerData['latitude']}, Lng: ${markerData['longitude']}",
          ),
        );
        markers.add(marker);
      }

      homeProvider.addJsonMarkers(markers);
    } catch (e) {
      print('Error al cargar los marcadores JSON: $e');
    }
  }

  Future<void> _handleLocationButtonPressed(BuildContext context, HomeProvider homeProvider, String uid) async {
    if (homeProvider.isTrackingLocation) {
      homeProvider.stopLocationTracking();
      _showSnackBar(context, 'Seguimiento de ubicación detenido', Colors.blue);
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(context, 'Por favor activa los servicios de ubicación.', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (homeProvider.deniedOnce) {
          bool shouldRequest = await _showPermissionRationaleDialog(context);
          if (!shouldRequest) return;
        }

        permission = await Geolocator.requestPermission();
        homeProvider.deniedOnce = true;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(context, 'Permiso denegado permanentemente. Actívalo desde ajustes.', Colors.red);
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        homeProvider.startPositionUpdates(uid);

        final currentPosition = await Geolocator.getCurrentPosition();
        await homeProvider.updateUserLocation(currentPosition, uid);

        _showSnackBar(context, 'Seguimiento de ubicación iniciado', Colors.green);
      }
    } catch (e) {
      _showSnackBar(context, 'Error: $e', Colors.red);
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

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showAvailableUsersList(BuildContext context, HomeProvider homeProvider) {
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
                  'Usuarios Disponibles (${homeProvider.availableUsers.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: homeProvider.availableUsers.isEmpty
                    ? const Center(child: Text('No hay usuarios disponibles'))
                    : ListView.builder(
                        itemCount: homeProvider.availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = homeProvider.availableUsers[index];
                          final distance = user['distance'] as double;
                          final distanceKm = distance / 1000;

                          final String firstNameStr = (user['firstName'] ?? '') as String;
                          final String lastNameStr = (user['lastName'] ?? '') as String;
                          final String initials = (() {
                            String s = '';
                            if (firstNameStr.isNotEmpty) s += firstNameStr[0].toUpperCase();
                            if (lastNameStr.isNotEmpty) s += lastNameStr[0].toUpperCase();
                            return s.isEmpty ? 'U' : s;
                          })();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                                  homeProvider.showUserOnMap(user);
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
