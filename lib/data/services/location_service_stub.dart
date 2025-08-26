import '../../domain/services/location_service.dart';


class StubLocationService implements LocationService {
@override
Future<void> ensurePermission() async {/* no-op */}


@override
Future<({double lat, double lng})?> getCurrentPosition() async {
// デモ座標
return (lat: 34.701909, lng: 135.494977); // 大阪駅付近（例）
}
}