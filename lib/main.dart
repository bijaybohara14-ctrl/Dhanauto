import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const DhanautoApp());
}

class DhanautoApp extends StatelessWidget {
  const DhanautoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dhanauto',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;

  LatLng? currentLocation;
  Marker? currentMarker;

  bool loadingLocation = true;

  final TextEditingController pickupController =
      TextEditingController(text: 'Getting current location...');

  final TextEditingController destinationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          loadingLocation = false;
          pickupController.text = 'Please turn on GPS';
        });
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          loadingLocation = false;
          pickupController.text = 'Location permission denied';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentLocation = location;
        currentMarker = Marker(
          markerId: const MarkerId('current_location'),
          position: location,
          infoWindow: const InfoWindow(
            title: 'Your current location',
          ),
        );

        pickupController.text =
            'Current location (${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)})';

        loadingLocation = false;
      });

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(location, 16),
        );
      }
    } catch (e) {
      setState(() {
        loadingLocation = false;
        pickupController.text = 'Unable to get location';
      });
    }
  }

  void findDhanauto() {
    if (destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter destination'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dhanauto'),
        content: const Text(
          'Ride search started.\n\nDriver matching will be connected next.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DHANAUTO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          // GOOGLE MAP
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(27.7172, 85.3240),
              zoom: 13,
            ),

            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,

            markers: currentMarker == null
                ? {}
                : {currentMarker!},

            onMapCreated: (GoogleMapController controller) {
              mapController = controller;

              if (currentLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    currentLocation!,
                    16,
                  ),
                );
              }
            },
          ),

          // SEARCH BOX
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: pickupController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.my_location,
                          color: Colors.blue,
                        ),
                        labelText: 'Pickup location',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: destinationController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                        labelText: 'Where to?',
                        hintText: 'Enter destination',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM BUTTON
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: loadingLocation
                    ? null
                    : findDhanauto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  loadingLocation
                      ? 'Getting location...'
                      : 'Find Dhanauto',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
