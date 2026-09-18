import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const String mapsApiKey = String.fromEnvironment(
  'MAPS_API_KEY',
  defaultValue: '',
);

const LatLng defaultCenter = LatLng(28.3949, 84.1240);

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const BookingPage(),
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  GoogleMapController? mapController;

  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  Timer? searchTimer;

  LatLng? pickupPosition;
  LatLng? destinationPosition;

  List<Map<String, dynamic>> suggestions = [];

  String activeField = '';

  Set<Marker> get markers {
    final result = <Marker>{};

    if (pickupPosition != null) {
      result.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupPosition!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
          onDragEnd: (position) {
            setState(() {
              pickupPosition = position;
              pickupController.text =
                  'Map location (${position.latitude.toStringAsFixed(5)}, '
                  '${position.longitude.toStringAsFixed(5)})';
            });
          },
        ),
      );
    }

    if (destinationPosition != null) {
      result.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationPosition!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: const InfoWindow(title: 'Destination'),
          onDragEnd: (position) {
            setState(() {
              destinationPosition = position;
              destinationController.text =
                  'Map location (${position.latitude.toStringAsFixed(5)}, '
                  '${position.longitude.toStringAsFixed(5)})';
            });
          },
        ),
      );
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showMessage('Phone ko GPS/Location ON गर्नुहोस्।');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage('Location permission दिनुहोस्।');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        pickupPosition = point;
        pickupController.text = 'Current location';
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 15),
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void activatePickup() {
    setState(() {
      activeField = 'pickup';
      suggestions = [];
    });
  }

  void activateDestination() {
    setState(() {
      activeField = 'destination';
      suggestions = [];
    });
  }

  void onSearchChanged(String value) {
    searchTimer?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        suggestions = [];
      });
      return;
    }

    searchTimer = Timer(
      const Duration(milliseconds: 500),
      () => searchPlaces(value.trim()),
    );
  }

  Future<void> searchPlaces(String input) async {
    if (mapsApiKey.isEmpty) {
      debugPrint('MAPS_API_KEY missing');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://places.googleapis.com/v1/places:autocomplete',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': mapsApiKey,
          'X-Goog-FieldMask':
              'suggestions.placePrediction.placeId,'
              'suggestions.placePrediction.text,'
              'suggestions.placePrediction.structuredFormat',
        },
        body: jsonEncode({
          'input': input,
          'languageCode': 'en',
        }),
      );

      debugPrint(
        'Places status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Places error: ${response.body}',
        );
        return;
      }

      final data = jsonDecode(response.body);
      final raw = data['suggestions'] ?? [];

      final results = <Map<String, dynamic>>[];

      for (final item in raw) {
        final prediction = item['placePrediction'];

        if (prediction != null) {
          final text =
              prediction['text']?['text'] ?? '';

          final placeId =
              prediction['placeId'];

          if (text.toString().isNotEmpty &&
              placeId != null) {
            results.add({
              'placeId': placeId,
              'text': text,
            });
          }
        }
      }

      if (!mounted) return;

      setState(() {
        suggestions = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  Future<void> selectPlace(
    Map<String, dynamic> place,
  ) async {
    final placeId = place['placeId'];

    if (placeId == null || mapsApiKey.isEmpty) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://places.googleapis.com/v1/places/$placeId',
        ),
        headers: {
          'X-Goog-Api-Key': mapsApiKey,
          'X-Goog-FieldMask':
              'location,displayName,formattedAddress',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Place details error: '
          '${response.statusCode} ${response.body}',
        );
        return;
      }

      final data = jsonDecode(response.body);
      final location = data['location'];

      if (location == null) return;

      final point = LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      );

      final name =
          data['displayName']?['text'] ??
          data['formattedAddress'] ??
          place['text'];

      if (!mounted) return;

      setState(() {
        if (activeField == 'pickup') {
          pickupPosition = point;
          pickupController.text = name.toString();
        } else {
          destinationPosition = point;
          destinationController.text = name.toString();
        }

        suggestions = [];
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 15),
      );
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  void onMapTap(LatLng point) {
    setState(() {
      if (activeField == 'pickup') {
        pickupPosition = point;
        pickupController.text =
            'Map location (${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)})';
      } else {
        destinationPosition = point;
        destinationController.text =
            'Map location (${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)})';
      }

      suggestions = [];
    });
  }

  void clearPickup() {
    setState(() {
      pickupPosition = null;
      pickupController.clear();
    });
  }

  void clearDestination() {
    setState(() {
      destinationPosition = null;
      destinationController.clear();
      suggestions = [];
    });
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void bookRide() {
    if (pickupPosition == null) {
      showMessage('Pickup location छान्नुहोस्।');
      return;
    }

    if (destinationPosition == null) {
      showMessage('Destination छान्नुहोस्।');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dhanauto भेटियो',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.electric_rickshaw),
                  ),
                  title: Text('Dhanauto E-Rickshaw'),
                  subtitle: Text('Driver खोजिँदैछ'),
                  trailing: Text(
                    'Rs. 120',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showMessage('Ride request पठाइयो!');
                    },
                    child: const Text('Confirm Ride'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget suggestionsBox() {
    if (suggestions.isEmpty) {
      return const SizedBox();
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 220,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black26,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = suggestions[index];

          return ListTile(
            leading: const Icon(
              Icons.location_on,
              color: Colors.red,
            ),
            title: Text(
              place['text'] ?? '',
            ),
            onTap: () {
              selectPlace(place);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dhanauto',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: getCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                const CameraPosition(
              target: defaultCenter,
              zoom: 7,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (controller) {
              mapController = controller;
            },
            onTap: onMapTap,
          ),

          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  activeField == 'pickup'
                      ? 'Pickup search वा map बाट location छान्नुहोस्'
                      : 'Destination search वा map बाट location छान्नुहोस्',
                ),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 15,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: pickupController,
                      onTap: activatePickup,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.my_location,
                        ),
                        labelText: 'Pickup location',
                        hintText: 'Search pickup location',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            pickupController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: clearPickup,
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: destinationController,
                      onTap: activateDestination,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.location_on,
                        ),
                        labelText: 'Where to?',
                        hintText: 'Search destination',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            destinationController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: clearDestination,
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                      ),
                    ),

                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      suggestionsBox(),
                    ],

                    const SizedBox(height: 8),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Map मा tap गर्नुहोस् वा marker drag गरेर exact location मिलाउनुहोस्।',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: bookRide,
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'Find Dhanauto',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
