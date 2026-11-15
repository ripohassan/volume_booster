import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/UI/controller/purchase_controller.dart';

class FakeGateway implements PurchaseGateway {
  int listeners = 0;
  int completions = 0;
  int buys = 0;
  late final StreamController<List<PurchaseDetails>> stream =
      StreamController.broadcast(onListen: () => listeners++);
  @override
  Stream<List<PurchaseDetails>> get updates => stream.stream;
  @override
  Future<List<ProductDetails>> products(Set<String> ids) async => [];
  @override
  Future<bool> buy(ProductDetails product) async {
    buys++;
    return true;
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completions++;
  }
}

class FakeVerifier implements EntitlementVerifier {
  @override
  bool isConfigured = true;
  List<VerifiedEntitlement> entitlements = [];
  bool fail = false;
  @override
  Future<List<VerifiedEntitlement>> verify({PurchaseDetails? purchase}) async {
    if (fail) throw StateError('Offline verification');
    return entitlements;
  }
}

class ChannelAppleVerifier extends NativeAppleEntitlementVerifier {
  @override
  bool get isConfigured => true;
}

PurchaseDetails purchase({
  String id = 'tx1',
  String product = 'v.booster.monthly',
}) => PurchaseDetails(
  purchaseID: id,
  productID: product,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'test-fixture',
    serverVerificationData: 'test-fixture',
    source: 'test',
  ),
  transactionDate: '2026-11-11',
  status: PurchaseStatus.purchased,
)..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late FakeVerifier verifier;
  late PurchaseController controller;
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({'is_premium_user': true});
    gateway = FakeGateway();
    verifier = FakeVerifier();
    now = DateTime.utc(2026, 11, 11);
    controller = PurchaseController(
      gateway: gateway,
      verifier: verifier,
      now: () => now,
    );
  });
  tearDown(() async {
    controller.dispose();
    await gateway.stream.close();
  });

  test(
    'Initialization subscribes once and never promotes a legacy boolean',
    () async {
      verifier.isConfigured = false;
      await Future.wait([controller.initialize(), controller.initialize()]);
      expect(gateway.listeners, 1);
      expect(controller.legacyRecordPresent, isTrue);
      expect(controller.hasSubscription, isFalse);
      expect(controller.state, PurchaseState.verificationRequired);
      expect(
        (await SharedPreferences.getInstance()).getBool('is_premium_user'),
        isTrue,
      );
      await expectLater(controller.buy('v.booster.monthly'), throwsStateError);
      expect(gateway.buys, 0);
    },
  );

  test(
    'Only a verified active known subscription grants paid access',
    () async {
      verifier.entitlements = [
        VerifiedEntitlement(
          transactionId: 'unknown',
          productId: 'other.product',
          expiresAt: now.add(const Duration(days: 1)),
        ),
        VerifiedEntitlement(
          transactionId: 'expired',
          productId: 'v.booster.monthly',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      ];
      await controller.initialize();
      expect(controller.hasSubscription, isFalse);
      verifier.entitlements = [
        VerifiedEntitlement(
          transactionId: 'tx1',
          productId: 'v.booster.monthly',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ];
      await controller.refresh();
      expect(controller.isPremium, isTrue);
      verifier.fail = true;
      await controller.refresh();
      expect(
        controller.hasSubscription,
        isTrue,
      ); // previously verified and unexpired
      now = now.add(const Duration(hours: 2));
      await controller.refresh();
      expect(controller.hasSubscription, isFalse);
    },
  );

  test('Unverified callbacks cannot grant or acknowledge a purchase', () async {
    await controller.initialize();
    gateway.stream.add([purchase()]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.hasSubscription, isFalse);
    expect(gateway.completions, 0);
  });

  test(
    'Verified purchase is acknowledged once, unrelated products ignored',
    () async {
      verifier.entitlements = [
        VerifiedEntitlement(
          transactionId: 'tx1',
          productId: 'v.booster.monthly',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ];
      await controller.initialize();
      gateway.stream.add([
        purchase(),
        purchase(),
        purchase(product: 'unrelated'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasSubscription, isTrue);
      expect(gateway.completions, 1);
    },
  );

  test('Refund/revocation refresh removes prior subscription access', () async {
    verifier.entitlements = [
      VerifiedEntitlement(
        transactionId: 'tx1',
        productId: 'v.booster.monthly',
        expiresAt: now.add(const Duration(days: 1)),
      ),
    ];
    await controller.initialize();
    expect(controller.hasSubscription, isTrue);
    verifier.entitlements = [];
    await controller.refresh();
    expect(controller.hasSubscription, isFalse);
  });

  test(
    'Rewarded access expires independently and is never a subscription',
    () async {
      await controller.initialize();
      await controller.setRewardExpiry(now.add(const Duration(hours: 1)));
      expect(controller.isPremium, isTrue);
      expect(controller.hasSubscription, isFalse);
      now = now.add(const Duration(hours: 2));
      expect(controller.isPremium, isFalse);
      await controller.setRewardExpiry(null);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'temp_premium_expiry',
        ),
        isNull,
      );
    },
  );

  test(
    'Native Apple bridge rejects unverified results and parses verified expiry',
    () async {
      const channel = MethodChannel('m.volume.booster/purchases');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final adapter = ChannelAppleVerifier();
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {'verified': false},
        ],
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await expectLater(adapter.verify(), throwsStateError);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {
            'verified': true,
            'revoked': false,
            'transactionId': 'tx1',
            'productId': 'v.booster.monthly',
            'expiresAtMs': now
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
        ],
      );
      expect(
        (await adapter.verify()).single.expiresAt,
        now.add(const Duration(hours: 1)),
      );
    },
  );
}
