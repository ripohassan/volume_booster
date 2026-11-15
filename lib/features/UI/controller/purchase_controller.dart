import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifiedEntitlement {
  final String transactionId;
  final String productId;
  final DateTime expiresAt;
  const VerifiedEntitlement({
    required this.transactionId,
    required this.productId,
    required this.expiresAt,
  });
}

/// Implementations must verify store evidence, expiry and revocation. A cached
/// local premium flag or an unverified purchase callback is not verification.
abstract interface class EntitlementVerifier {
  bool get isConfigured;
  Future<List<VerifiedEntitlement>> verify({PurchaseDetails? purchase});
}

class NativeAppleEntitlementVerifier implements EntitlementVerifier {
  static const _channel = MethodChannel('m.volume.booster/purchases');
  @override
  bool get isConfigured => Platform.isIOS;

  @override
  Future<List<VerifiedEntitlement>> verify({PurchaseDetails? purchase}) async {
    if (!isConfigured) {
      throw StateError('Configure a trusted Android subscription verifier');
    }
    final records = await _channel.invokeListMethod<dynamic>(
      'currentEntitlements',
    );
    if (records == null) {
      throw StateError('No entitlement verification response');
    }
    return records.map((value) {
      final record = Map<String, dynamic>.from(value as Map);
      if (record['verified'] != true || record['revoked'] != false) {
        throw StateError('Unverified store entitlement');
      }
      return VerifiedEntitlement(
        transactionId: record['transactionId'] as String,
        productId: record['productId'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          record['expiresAtMs'] as int,
          isUtc: true,
        ),
      );
    }).toList();
  }
}

abstract interface class PurchaseGateway {
  Stream<List<PurchaseDetails>> get updates;
  Future<List<ProductDetails>> products(Set<String> ids);
  Future<bool> buy(ProductDetails product);
  Future<void> restore();
  Future<void> complete(PurchaseDetails purchase);
}

class StorePurchaseGateway implements PurchaseGateway {
  InAppPurchase get _store => InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get updates => _store.purchaseStream;
  @override
  Future<List<ProductDetails>> products(Set<String> ids) async {
    if (!await _store.isAvailable()) throw StateError('Store is unavailable');
    final response = await _store.queryProductDetails(ids);
    if (response.error != null) throw StateError(response.error!.message);
    return response.productDetails;
  }

  @override
  Future<bool> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );
  @override
  Future<void> restore() => _store.restorePurchases();
  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

enum PurchaseState {
  checking,
  free,
  premium,
  pending,
  verificationRequired,
  error,
}

/// Sole purchase-stream subscriber and entitlement owner. Receipts stay in the
/// store; only a fresh trusted verification establishes subscription access.
class PurchaseController extends ChangeNotifier with WidgetsBindingObserver {
  static PurchaseController _shared = PurchaseController();
  static PurchaseController get shared => _shared;

  /// Configure a trusted Android verifier before application startup. Never
  /// replace an owner that already has a store subscription.
  static void configureVerifier(EntitlementVerifier verifier) {
    if (_shared._initialization != null) {
      throw StateError('Configure verification before startup');
    }
    _shared.dispose();
    _shared = PurchaseController(verifier: verifier);
  }

  static const productIds = {
    'v.booster.weekly',
    'v.booster.monthly',
    'v.booster.yearly',
  };
  final PurchaseGateway gateway;
  final EntitlementVerifier verifier;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Timer? _expiryTimer;
  Future<void>? _initialization;
  Future<void> _events = Future.value();
  Future<void> _verifications = Future.value();
  int _verifiedSnapshot = 0;
  List<VerifiedEntitlement> _entitlements = const [];
  List<ProductDetails> _products = const [];
  final Set<String> _completed = {};
  DateTime? _rewardUntil;
  bool _legacyRecordPresent = false;
  bool _disposed = false;
  Object? _error;
  PurchaseState _state = PurchaseState.checking;

  PurchaseController({
    PurchaseGateway? gateway,
    EntitlementVerifier? verifier,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : gateway = gateway ?? StorePurchaseGateway(),
       verifier = verifier ?? NativeAppleEntitlementVerifier(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  PurchaseState get state => _state;
  Object? get error => _error;
  bool get legacyRecordPresent => _legacyRecordPresent;
  bool get hasSubscription => _entitlements.any(
    (e) => productIds.contains(e.productId) && e.expiresAt.isAfter(_now()),
  );
  bool get hasRewardAccess => _rewardUntil?.isAfter(_now()) ?? false;
  bool get isPremium => hasSubscription || hasRewardAccess;
  List<ProductDetails> get products => _products;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final prefs = await _preferences();
      if (_disposed) return;
      WidgetsBinding.instance.addObserver(this);
      _legacyRecordPresent = prefs.getBool('is_premium_user') ?? false;
      _rewardUntil = DateTime.tryParse(
        prefs.getString('temp_premium_expiry') ?? '',
      );
      _subscription = gateway.updates.listen(
        (updates) {
          _events = _events.then((_) => _handle(updates)).catchError((
            Object error,
          ) {
            _error = error;
            _state = PurchaseState.error;
            _notify();
          });
        },
        onError: (Object error) {
          _error = error;
          _state = PurchaseState.error;
          _notify();
        },
      );
      await refresh();
    } catch (error) {
      _error = error;
      _state = PurchaseState.error;
      _notify();
    }
  }

  Future<void> refresh({PurchaseDetails? purchase}) {
    final result = _verifications.then((_) => _verify(purchase));
    _verifications = result.catchError((Object error) {});
    return result;
  }

  Future<void> _verify(PurchaseDetails? purchase) async {
    if (_disposed) return;
    if (!verifier.isConfigured) {
      _state = PurchaseState.verificationRequired;
      _scheduleExpiry();
      _notify();
      return;
    }
    _state = PurchaseState.checking;
    _notify();
    try {
      final verified = await verifier
          .verify(purchase: purchase)
          .timeout(const Duration(seconds: 15));
      if (_disposed) return;
      _entitlements = List.unmodifiable(
        verified.where(
          (e) =>
              productIds.contains(e.productId) &&
              e.transactionId.isNotEmpty &&
              e.expiresAt.isAfter(_now()),
        ),
      );
      _verifiedSnapshot++;
      _error = null;
      _state = hasSubscription ? PurchaseState.premium : PurchaseState.free;
    } catch (error) {
      // A transient store error does not erase an already verified, unexpired
      // in-memory entitlement. No local bool or unverified cache is promoted.
      _error = error;
      _state = hasSubscription
          ? PurchaseState.premium
          : PurchaseState.verificationRequired;
    }
    _scheduleExpiry();
    _notify();
  }

  Future<void> _handle(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (_disposed || !productIds.contains(purchase.productID)) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _state = PurchaseState.pending;
        _notify();
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _error = purchase.error;
        _state = hasSubscription ? PurchaseState.premium : PurchaseState.free;
        _notify();
        continue;
      }
      final previousSnapshot = _verifiedSnapshot;
      await refresh(purchase: purchase);
      final verifiedProduct = _verifiedSnapshot > previousSnapshot && _entitlements.any(
        (e) =>
            e.productId == purchase.productID &&
            e.transactionId == purchase.purchaseID &&
            e.expiresAt.isAfter(_now()),
      );
      final key =
          '${purchase.productID}:${purchase.purchaseID}:${purchase.transactionDate}';
      if (verifiedProduct &&
          purchase.pendingCompletePurchase &&
          !_completed.contains(key)) {
        await gateway.complete(purchase);
        _completed.add(key);
      }
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiries = [
      for (final e in _entitlements) e.expiresAt,
      if (_rewardUntil != null) _rewardUntil!,
    ].where((date) => date.isAfter(_now())).toList()..sort();
    if (expiries.isEmpty || _disposed) return;
    _expiryTimer = Timer(expiries.first.difference(_now()), () {
      _state = hasSubscription ? PurchaseState.premium : PurchaseState.free;
      _notify();
      unawaited(refresh());
    });
  }

  Future<List<ProductDetails>> loadProducts() async {
    await initialize();
    final result = await gateway.products(productIds);
    _products = List.unmodifiable(
      result.where((p) => productIds.contains(p.id)),
    );
    _notify();
    return _products;
  }

  Future<void> buy(String productId) async {
    await initialize();
    if (!productIds.contains(productId)) {
      throw ArgumentError('Unknown subscription product');
    }
    if (!verifier.isConfigured) {
      throw StateError(
        'Subscription verification is not configured for this platform',
      );
    }
    if (!_products.any((p) => p.id == productId)) await loadProducts();
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Subscription product is unavailable'),
    );
    if (!await gateway.buy(product)) {
      throw StateError('Store could not start the purchase');
    }
  }

  Future<void> restore() async {
    await initialize();
    if (!verifier.isConfigured) {
      throw StateError(
        'Subscription verification is not configured for this platform',
      );
    }
    await gateway.restore();
    await _events;
    await refresh();
  }

  Future<void> setRewardExpiry(DateTime? expiry) async {
    final prefs = await _preferences();
    if (expiry == null) {
      await prefs.remove('temp_premium_expiry');
    } else {
      await prefs.setString(
        'temp_premium_expiry',
        expiry.toUtc().toIso8601String(),
      );
    }
    _rewardUntil = expiry;
    _scheduleExpiry();
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_disposed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
