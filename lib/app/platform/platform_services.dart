/// Plattformabhängige Dienste (Handy vs. Browser).
library;

export 'platform_services_io.dart'
    if (dart.library.js_interop) 'platform_services_web.dart';
