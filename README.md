# Dhanauto Maps MVP

यो version मा Google Maps booking screen जोडिएको छ।

## चलाउन
1. Flutter install गर्नुहोस्।
2. `flutter pub get`
3. Google Maps API key बनाएर Android/iOS मा configure गर्नुहोस्।
4. `flutter run`

## API key
Android: `android/app/src/main/AndroidManifest.xml` मा Google Maps API key राख्नुपर्छ।
iOS: `ios/Runner/AppDelegate.swift` मा Maps API key configure गर्नुपर्छ।

## अहिले के चल्छ
- Google Map screen
- Pickup/destination input
- Find Dhanauto
- Vehicle/fare confirmation bottom sheet

## Production मा थपिने
- GPS permission + user's real location
- Place search/autocomplete
- Distance-based fare
- Firebase OTP/login
- Driver app
- Real-time driver matching
- Live driver tracking
- Payment gateway
- Admin dashboard
