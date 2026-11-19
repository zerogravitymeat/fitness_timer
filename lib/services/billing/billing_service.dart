import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'entitlement_service.dart';

enum BuyResult { purchased, pending, canceled, failed, unavailable }

/// Google Play 인앱 결제 (docs/02_기능_명세.md 10.5절, docs/05 7장).
///
/// - 비소모성 상품 하나(`full_version`)를 한 번 구매로 판다.
/// - 앱을 시작할 때 구매 내역을 조회해 정식 버전 여부를 정한다.
///   조회에 실패하면(오프라인 등) 마지막으로 저장한 값을 그대로 쓴다.
/// - 환불되어 구매 내역이 사라지면 다음 조회 때 체험 종료 상태로 돌아간다.
/// - 서버 영수증 검증은 MVP에서 하지 않는다.
class BillingService extends ChangeNotifier {
  BillingService(this._entitlement);

  /// Play Console에 만들 상품 ID (임시)
  static const productId = 'full_version';

  final EntitlementService _entitlement;
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<BuyResult>? _pendingBuy;

  bool _available = false;
  ProductDetails? _product;
  String? _lastError;

  /// 스토어에 연결할 수 있고 상품 정보도 받았는지
  bool get canBuy => _available && _product != null;
  bool get storeAvailable => _available;

  /// Google Play에서 받은 현지 가격 (예: "₩5,900"). 앱에 적어두지 않는다 (docs/03 S6)
  String? get price => _product?.price;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('BillingService: $e'),
    );
    await refresh();
  }

  /// 스토어 연결, 상품 정보, 구매 내역을 다시 확인한다
  Future<void> refresh() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        _lastError = 'Google Play에 연결할 수 없어요';
        notifyListeners();
        return;
      }
      final res = await _iap.queryProductDetails({productId});
      _product = res.productDetails.where((p) => p.id == productId).firstOrNull;
      _lastError =
          res.error?.message ??
          (_product == null ? '상품 정보를 찾을 수 없어요 ($productId)' : null);
      await _syncPastPurchases();
    } catch (e) {
      _lastError = '$e';
    }
    notifyListeners();
  }

  /// 구매 내역으로 정식 버전 여부를 맞춘다. 조회에 실패하면 저장된 값을 유지한다.
  Future<void> _syncPastPurchases() async {
    final android = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final res = await android.queryPastPurchases();
    if (res.error != null) return; // 오프라인 등: 마지막 값 유지
    var owned = false;
    for (final p in res.pastPurchases) {
      final w = p.billingClientPurchase;
      if (w.products.contains(productId) &&
          w.purchaseState == PurchaseStateWrapper.purchased) {
        owned = true;
        // 확정되지 않은 구매는 3일 뒤 자동 환불되므로 여기서도 확정한다
        if (!w.isAcknowledged) await _iap.completePurchase(p);
      }
    }
    await _entitlement.setFull(owned);
  }

  Future<BuyResult> buy() async {
    final product = _product;
    if (!_available || product == null) return BuyResult.unavailable;
    _pendingBuy = Completer<BuyResult>();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) return BuyResult.failed;
    } catch (e) {
      _lastError = '$e';
      return BuyResult.failed;
    }
    return _pendingBuy!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => BuyResult.failed,
    );
  }

  /// 구매 복원 (docs/03 S5, S6)
  Future<void> restore() async {
    if (!_available) await refresh();
    if (!_available) return;
    await _iap.restorePurchases();
    await _syncPastPurchases();
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _entitlement.setFull(true);
          _finish(BuyResult.purchased);
        case PurchaseStatus.pending:
          // 편의점 결제 등 승인 대기. 승인되면 다시 purchased로 온다.
          _finish(BuyResult.pending);
        case PurchaseStatus.canceled:
          _finish(BuyResult.canceled);
        case PurchaseStatus.error:
          _lastError = p.error?.message;
          _finish(BuyResult.failed);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    notifyListeners();
  }

  void _finish(BuyResult r) {
    final c = _pendingBuy;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
