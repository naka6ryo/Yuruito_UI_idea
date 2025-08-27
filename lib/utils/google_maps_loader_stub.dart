// Stub loader for non-web platforms. Maps JS is only relevant on web, so this
// immediately returns a completed future.
Future<void> waitForMapsImpl({Duration? timeout}) async => Future.value();
