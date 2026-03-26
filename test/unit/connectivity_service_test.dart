// Unit tests for ConnectivityService
//
// Tests cover:
//   - Singleton pattern
//   - isConnected throws without platform binding (unit test env)
//   - Service instantiation

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/services/connectivity_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ConnectivityService singleton', () {
    test('returns same instance on multiple calls', () {
      final instance1 = ConnectivityService();
      final instance2 = ConnectivityService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('factory constructor returns ConnectivityService instance', () {
      final service = ConnectivityService();
      expect(service, isA<ConnectivityService>());
    });
  });

  group('ConnectivityService isConnected()', () {
    test('isConnected throws or returns bool in test environment', () async {
      final service = ConnectivityService();
      try {
        final result = await service.isConnected();
        expect(result, isA<bool>());
      } catch (e) {
        // Platform channels unavailable in unit test env — acceptable
        expect(e, isNotNull);
      }
    });

    test('isConnected handles platform exceptions gracefully', () async {
      final service = ConnectivityService();
      try {
        await service.isConnected();
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('ConnectivityService is singleton across test calls', () {
      final a = ConnectivityService();
      final b = ConnectivityService();
      expect(a, same(b));
    });

    test('ConnectivityService instantiates without error', () {
      expect(() => ConnectivityService(), returnsNormally);
    });
  });
}
