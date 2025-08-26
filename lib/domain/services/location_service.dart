abstract class LocationService {
Future<void> ensurePermission();
Future<({double lat, double lng})?> getCurrentPosition();
}