import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class TrackingPage extends StatefulWidget {
  final String trackedUid;

  const TrackingPage({super.key, required this.trackedUid});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  LatLng? trackedPosition;
  StreamSubscription<DatabaseEvent>? _sub;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final ref = FirebaseDatabase.instance.ref('users/${widget.trackedUid}');
    _sub = ref.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final lat = (data['latitude'] ?? 0.0).toDouble();
        final lng = (data['longitude'] ?? 0.0).toDouble();
        setState(() {
          trackedPosition = LatLng(lat, lng);
          _markers.clear();
          _markers.add(Marker(
            markerId: MarkerId(widget.trackedUid),
            position: trackedPosition!,
            infoWindow: InfoWindow(title: data['firstName'] ?? 'Usuario'),
          ));
        });
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(trackedPosition!));
        }
      }
    }, onError: (e) {
      // ignorar
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.0, 0.0),
    zoom: 14.4,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: GoogleMap(
        initialCameraPosition: trackedPosition != null
            ? CameraPosition(target: trackedPosition!, zoom: 14.4)
            : _initialPosition,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
          if (trackedPosition != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(trackedPosition!));
          }
        },
      ),
    );
  }
}
