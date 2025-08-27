import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Inject Google Maps JS API script if missing, then wait until `window.google.maps` is available.
Future<void> waitForMapsImpl({Duration? timeout}) async {
  // If already available, return immediately.
  final google = js_util.getProperty(html.window, 'google');
  if (google != null && js_util.getProperty(google, 'maps') != null) return;

  // Try injecting the script. Use an API key provided by dart-define if available.
  // Use dart-define if provided; otherwise fall back to the key supplied by the user.
  final key = const String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'AIzaSyDCRDDdgwlnVcVW4mgRGqGdrTaw0DnsntI');
  final src = key.isNotEmpty
      ? 'https://maps.googleapis.com/maps/api/js?key=$key&libraries=places'
      : 'https://maps.googleapis.com/maps/api/js?libraries=places';

  // Avoid duplicate script tags.
  final existing = html.document.querySelectorAll('script').where((e) => (e as html.ScriptElement).src.contains('maps.googleapis.com')).toList();
  if (existing.isEmpty) {
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = src
      ..async = true;
    html.document.head!.append(script);
  }

  final end = DateTime.now().add(timeout ?? const Duration(seconds: 8));
  while (DateTime.now().isBefore(end)) {
    final g = js_util.getProperty(html.window, 'google');
    if (g != null) {
      final maps = js_util.getProperty(g, 'maps');
      if (maps != null) return;
    }
    await Future.delayed(const Duration(milliseconds: 150));
  }
  throw StateError('Google Maps JS API not loaded (window.google.maps is undefined).');
}
