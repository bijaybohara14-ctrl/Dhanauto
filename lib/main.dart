import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const String mapsApiKey =
    String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

const LatLng defaultCenter = LatLng(28.70, 80.60);

// Dhanauto service/search area:
// Mahendranagar → Fulbari → Dhangadhi → Karnali आसपास
const double minLat = 28.20;
const double minLng = 80.00;
const double maxLat = 30.80;
const double maxLng = 82.90;

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
      home: const DhanautoHome(),
    );
  }
}

class DhanautoHome extends StatefulWidget {
  const DhanautoHome({super.key});

  @override
  State<DhanautoHome> createState() => _DhanautoHomeState();
}

class _DhanautoHomeState extends State<DhanautoHome> {
  GoogleMapController? mapController;

  LatLng pickup = defaultCenter;
  LatLng? destination;

  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  Timer? searchTimer;
  String activeField = 'pickup';
  bool searching = false;

  List<Map<String, dynamic>> suggestions = [];

  Set<Marker> get markers {
    final result = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        draggable: true,
        infoWindow: const InfoWindow(title: 'Pickup'),
        onDragEnd: (p) {
          if (_insideArea(p)) {
            setState(() => pickup = p);
          }
        },
      ),
    };

    if (destination != null) {
      result.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination!,
          draggable: true,
          infoWindow: const InfoWindow(title: 'Destination'),
          onDragEnd: (p) {
            if (_insideArea(p)) {
              setState(() => destination = p);
            }
          },
        ),
      );
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  bool _insideArea(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      final current = LatLng(
        position.latitude,
        position.longitude,
      );

      if (_insideArea(current)) {
        setState(() {
          pickup = current;
        });

        await mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(current, 13),
        );
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    searchTimer?.cancel();

    searchTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        searchPlaces(value);
      },
    );
  }

  Future<void> searchPlaces(String input) async {
    if (mapsApiKey.isEmpty || input.trim().length < 2) {
      setState(() {
        suggestions = [];
        searching = false;
      });
      return;
    }

    setState(() {
      searching = true;
    });

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
          'input': input.trim(),
          'languageCode': 'en',

          // Strict rectangle:
          // Mahendranagar + Fulbari + Dhangadhi + Karnali आसपास
          'locationRestriction': {
            'rectangle': {
              'low': {
                'latitude': minLat,
                'longitude': minLng,
              },
              'high': {
                'latitude': maxLat,
                'longitude': maxLng,
              },
            },
          },
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          suggestions = [];
          searching = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      final rawSuggestions =
          data['suggestions'] as List? ?? [];

      final results = <Map<String, dynamic>>[];

      for (final item in rawSuggestions) {
        final prediction = item['placePrediction'];

        if (prediction == null) continue;

        final placeId = prediction['placeId'];
        final text = prediction['text']?['text'];

        if (placeId != null && text != null) {
          results.add({
            'placeId': placeId,
            'text': text,
          });
        }
      }

      if (mounted) {
        setState(() {
          suggestions = results;
          searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          suggestions = [];
          searching = false;
        });
      }
    }
  }

  Future<void> selectPlace(
    Map<String, dynamic> place,
  ) async {
    if (mapsApiKey.isEmpty) return;

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places/${place['placeId']}',
      );

      final response = await http.get(
        uri,
        headers: {
          'X-Goog-Api-Key': mapsApiKey,
          'X-Goog-FieldMask':
              'id,displayName,location',
        },
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final location = data['location'];

      if (location == null) return;

      final point = LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      );

      if (!_insideArea(point)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'यो location Dhanauto service area बाहिर छ।',
              ),
            ),
          );
        }
        return;
      }

      final name =
          data['displayName']?['text'] ??
          place['text'];

      setState(() {
        if (activeField == 'pickup') {
          pickup = point;
          pickupController.text = name;
        } else {
          destination = point;
          destinationController.text = name;
        }

        suggestions = [];
      });

      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 14),
      );
    } catch (_) {}
  }

  void _onMapTap(LatLng point) {
    if (!_insideArea(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'यो Dhanauto service area बाहिर छ।',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (activeField == 'pickup') {
        pickup = point;
      } else {
        destination = point;
      }
    });
  }

  void _findDhanauto() {
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'पहिला destination छान्नुहोस्।',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.electric_rickshaw,
                    color: Colors.red,
                    size: 36,
                  ),
                  title: Text(
                    'Dhanauto E-Rickshaw',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text('Estimated fare'),
                  trailing: Text(
                    'Rs. 120',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ride request पठाइयो!',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Request Dhanauto',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String hint,
    required String fieldName,
    required IconData icon,
  }) {
    final isActive = activeField == fieldName;

    return TextField(
      controller: controller,
      onTap: () {
        setState(() {
          activeField = fieldName;
          suggestions = [];
        });
      },
      onChanged: (value) {
        setState(() {
          activeField = fieldName;
        });

        _onSearchChanged(value);
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  controller.clear();

                  setState(() {
                    suggestions = [];
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isActive
                ? Colors.red
                : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: defaultCenter,
              zoom: 9.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (controller) {
              mapController = controller;
            },
            onTap: _onMapTap,
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    0,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.electric_rickshaw,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dhanauto',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Mahendranagar • Fulbari • Dhangadhi • Karnali',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _locationField(
                        controller: pickupController,
                        hint: 'Pickup location',
                        fieldName: 'pickup',
                        icon: Icons.my_location,
                      ),
                      const SizedBox(height: 9),
                      _locationField(
                        controller:
                            destinationController,
                        hint: 'Where to?',
                        fieldName: 'destination',
                        icon: Icons.location_on,
                      ),

                      if (searching)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child:
                              LinearProgressIndicator(),
                        ),

                      if (suggestions.isNotEmpty)
                        Container(
                          margin:
                              const EdgeInsets.only(
                            top: 8,
                          ),
                          constraints:
                              const BoxConstraints(
                            maxHeight: 220,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black12,
                            ),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount:
                                suggestions.length,
                            separatorBuilder:
                                (_, __) =>
                                    const Divider(
                                  height: 1,
                                ),
                            itemBuilder:
                                (context, index) {
                              final item =
                                  suggestions[index];

                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons
                                      .location_on_outlined,
                                ),
                                title: Text(
                                  item['text'],
                                ),
                                onTap: () =>
                                    selectPlace(item),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                Container(
                  margin: const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    12,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Map मा tap गर्नुहोस् वा marker drag गर्नुहोस्।',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _findDhanauto,
                          icon: const Icon(
                            Icons.search,
                          ),
                          label: const Text(
                            'Find Dhanauto',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
