// Conditional import delegator: uses the web implementation when compiled for web,
// otherwise uses the stub that immediately completes.
import 'google_maps_loader_stub.dart' if (dart.library.html) 'google_maps_loader_web.dart';

/// Wait until Google Maps JS API is ready on web; on other platforms this
/// completes immediately. Implementation is provided by the conditional import.
Future<void> waitForMaps({Duration? timeout}) => waitForMapsImpl(timeout: timeout);

// The platform-specific files must provide this function.
Future<void> waitForMapsImpl({Duration? timeout}) async => Future.value();
