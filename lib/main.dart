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

const LatLng defaultCenter = LatLng(28.70, 80.60);

// Dhangadhi • Fulbari • Mahendranagar • Karnali area
const double minLat = 28.20;
const double minLng = 80.00;
const double maxLat = 30.80;
const double maxLng = 82.90;

bool _insideArea(LatLng p) {
  return p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;
}

class DhanautoApp extends StatelessWidget {
  const DhanautoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dhanauto',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
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

  final TextEditingController pickupController =
      TextEditingController();

  final TextEditingController destinationController =
      TextEditingController();

  Timer? searchTimer;
  StreamSubscription<Position>? positionStream;

  String activeField = 'pickup';

  LatLng? currentLocation;
  LatLng? pickupLocation;
  LatLng? destinationLocation;

  Set<Marker> markers = {};
  List<Map<String, dynamic>> suggestions = [];

  bool searching = false;
  bool gettingLocation = false;
  bool followLiveLocation = true;

  @override
  void initState() {
    super.initState();
    _startLiveLocation();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    searchTimer?.cancel();

    pickupController.dispose();
    destinationController.dispose();

    super.dispose();
  }

  Future<void> _startLiveLocation() async {
    if (!mounted) return;

    setState(() {
      gettingLocation = true;
      followLiveLocation = true;
    });

    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      setState(() {
        gettingLocation = false;
      });

      _showMessage(
        'Location service ON गर्नुहोस्।',
      );

      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      setState(() {
        gettingLocation = false;
      });

      _showMessage(
        'Live location permission चाहिन्छ।',
      );

      return;
    }

    try {
      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final LatLng live = LatLng(
        position.latitude,
        position.longitude,
      );

      if (_insideArea(live)) {
        if (!mounted) return;

        setState(() {
          currentLocation = live;
          pickupLocation = live;
          pickupController.text =
              'My live location';
        });

        _updateMarkers();

        await mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            live,
            15,
          ),
        );
      } else {
        _showMessage(
          'तपाईंको location Dhanauto service area बाहिर छ।',
        );
      }

      await positionStream?.cancel();

      positionStream =
          Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (Position position) {
          final LatLng live = LatLng(
            position.latitude,
            position.longitude,
          );

          if (!_insideArea(live)) {
            return;
          }

          if (!mounted) return;

          setState(() {
            currentLocation = live;

            if (followLiveLocation) {
              pickupLocation = live;
              pickupController.text =
                  'My live location';
            }
          });

          _updateMarkers();

          if (followLiveLocation &&
              mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newLatLng(
                live,
              ),
            );
          }
        },
      );
    } catch (e) {
      _showMessage(
        'Live location लिन सकिएन।',
      );
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation = false;
        });
      }
    }
  }

  void _updateMarkers() {
    final Set<Marker> newMarkers = {};

    if (pickupLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation!,
          draggable: false,
          infoWindow: const InfoWindow(
            title: 'A - Pickup',
          ),
        ),
      );
    }

    if (destinationLocation != null) {
      newMarkers.add(
        Marker(
          markerId:
              const MarkerId('destination'),
          position: destinationLocation!,
          draggable: true,
          infoWindow: const InfoWindow(
            title: 'B - Destination',
          ),
          onDragEnd: (LatLng newPosition) {
            if (!_insideArea(newPosition)) {
              _showMessage(
                'यो location service area बाहिर छ।',
              );
              return;
            }

            if (!mounted) return;

            setState(() {
              destinationLocation =
                  newPosition;
            });

            _updateMarkers();
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        markers = newMarkers;
      });
    }
  }

  void _onMapTap(LatLng position) {
    if (!_insideArea(position)) {
      _showMessage(
        'यो location Dhanauto service area बाहिर छ।',
      );
      return;
    }

    if (activeField == 'pickup') {
      setState(() {
        followLiveLocation = false;
        pickupLocation = position;
        pickupController.text =
            'Selected location';
      });
    } else {
      setState(() {
        destinationLocation = position;
        destinationController.text =
            'Selected location';
      });
    }

    _updateMarkers();
  }

  void _onTextChanged(String value) {
    searchTimer?.cancel();

    if (value.trim().length < 2) {
      if (!mounted) return;

      setState(() {
        suggestions = [];
      });

      return;
    }

    searchTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        searchPlaces(value.trim());
      },
    );
  }

  Future<void> searchPlaces(
    String input,
  ) async {
    if (mapsApiKey.isEmpty) {
      return;
    }

    if (!mounted) return;

    setState(() {
      searching = true;
    });

    try {
      final Uri url = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );

      final response = await http.post(
        url,
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
        if (mounted) {
          setState(() {
            suggestions = [];
          });
        }

        return;
      }

      final data =
          jsonDecode(response.body);

      final List<Map<String, dynamic>>
          result = [];

      final List<dynamic> list =
          data['suggestions'] ?? [];

      for (final item in list) {
        final prediction =
            item['placePrediction'];

        if (prediction == null) {
          continue;
        }

        result.add({
          'placeId':
              prediction['placeId'],
          'text':
              prediction['text']?['text'] ??
                  '',
        });
      }

      if (mounted) {
        setState(() {
          suggestions = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          suggestions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          searching = false;
        });
      }
    }
  }

  Future<void> selectPlace(
    Map<String, dynamic> suggestion,
  ) async {
    if (mapsApiKey.isEmpty) {
      return;
    }

    final String placeId =
        suggestion['placeId'] ?? '';

    if (placeId.isEmpty) {
      return;
    }

    try {
      final Uri url = Uri.parse(
        'https://places.googleapis.com/v1/places/$placeId',
      );

      final response = await http.get(
        url,
        headers: {
          'X-Goog-Api-Key': mapsApiKey,
          'X-Goog-FieldMask':
              'id,displayName,location',
        },
      );

      if (response.statusCode != 200) {
        _showMessage(
          'Location खोज्न सकिएन।',
        );

        return;
      }

      final data =
          jsonDecode(response.body);

      final location = data['location'];

      if (location == null) {
        return;
      }

      final LatLng point = LatLng(
        (location['latitude'] as num)
            .toDouble(),
        (location['longitude'] as num)
            .toDouble(),
      );

      if (!_insideArea(point)) {
        _showMessage(
          'यो location service area बाहिर छ।',
        );

        return;
      }

      final String name =
          data['displayName']?['text'] ??
              suggestion['text'] ??
              'Selected location';

      if (!mounted) return;

      setState(() {
        if (activeField == 'pickup') {
          followLiveLocation = false;
          pickupLocation = point;
          pickupController.text = name;
        } else {
          destinationLocation = point;
          destinationController.text = name;
        }

        suggestions = [];
      });

      _updateMarkers();

      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          point,
          15,
        ),
      );
    } catch (e) {
      _showMessage(
        'Location select गर्न सकिएन।',
      );
    }
  }

  Widget _locationField({
    required TextEditingController controller,
    required String hint,
    required String fieldName,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      onTap: () {
        setState(() {
          activeField = fieldName;
        });
      },
      onChanged: _onTextChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _findDhanauto() {
    if (pickupLocation == null) {
      _showMessage(
        'पहिला A pickup location राख्नुहोस्।',
      );

      return;
    }

    if (destinationLocation == null) {
      _showMessage(
        'पहिला B destination location राख्नुहोस्।',
      );

      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                'Dhanauto E-Rickshaw',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Estimated fare',
                style: TextStyle(
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              const Text(
                'Rs. 120',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Ride request पठाइयो!',
                    );
                  },
                  child: const Text(
                    'Request Dhanauto',
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                const CameraPosition(
              target: defaultCenter,
              zoom: 8,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled:
                true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            markers: markers,

            onMapCreated:
                (controller) {
              mapController =
                  controller;

              if (currentLocation !=
                  null) {
                controller.animateCamera(
                  CameraUpdate
                      .newLatLngZoom(
                    currentLocation!,
                    15,
                  ),
                );
              }
            },

            onTap: _onMapTap,
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  margin:
                      const EdgeInsets.all(
                    12,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black
                            .withOpacity(
                          0.15,
                        ),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration:
                            const BoxDecoration(
                          color: Colors.red,
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            const Icon(
                          Icons
                              .electric_rickshaw,
                          color:
                              Colors.white,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Dhanauto',
                              style:
                                  TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            Text(
                              'Mahendranagar • Fulbari • Dhangadhi • Karnali',
                              style:
                                  TextStyle(
                                fontSize: 11,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      _locationField(
                        controller:
                            pickupController,
                        hint: 'A',
                        fieldName:
                            'pickup',
                        icon:
                            Icons.my_location,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _locationField(
                        controller:
                            destinationController,
                        hint: 'B',
                        fieldName:
                            'destination',
                        icon:
                            Icons.location_on,
                      ),

                      if (searching)
                        Container(
                          margin:
                              const EdgeInsets
                                  .only(
                            top: 5,
                          ),
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          color:
                              Colors.white,
                          child:
                              const LinearProgressIndicator(),
                        ),

                      if (suggestions
                          .isNotEmpty)
                        Container(
                          margin:
                              const EdgeInsets
                                  .only(
                            top: 5,
                          ),
     
