import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(const DhanautoApp());

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
  final pickup = TextEditingController();
  final destination = TextEditingController();

  static const LatLng defaultCenter = LatLng(27.7172, 85.3240);

  void bookRide() {
    if (pickup.text.trim().isEmpty || destination.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup र destination भर्नुहोस्')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Dhanauto भेटियो', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.electric_rickshaw)),
              title: Text('Dhanauto E-Rickshaw'),
              subtitle: Text('Driver खोजिँदैछ • ETA लगभग 3–5 min'),
              trailing: Text('Rs. 120', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ride request पठाइयो!')),
                  );
                },
                child: const Text('Confirm Ride'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dhanauto', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))],
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: defaultCenter, zoom: 13),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) => mapController = c,
        ),
        Positioned(
          left: 16, right: 16, bottom: 18,
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                  controller: pickup,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.my_location),
                    labelText: 'Pickup location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: destination,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on),
                    labelText: 'Where to?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    onPressed: bookRide,
                    icon: const Icon(Icons.search),
                    label: const Text('Find Dhanauto'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
