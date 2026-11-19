import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../design/app_icon_painter.dart';
import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../services/billing/billing_service.dart';

/// S6 정식 버전 구매 (docs/03_화면_설계.md 7-1장). 기능 확인용 기본 UI.
/// 구매가 끝나면 `true`를 돌려준다 → 부른 쪽은 하려던 동작을 이어간다.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  /// 결제 화면을 열고, 정식 버전이 되었으면 true
  static Future<bool> open(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PaywallPage(),
        fullscreenDialog: true,
      ),
    );
    return ok == true || AppServices.entitlement.value.isFull;
  }

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  BillingService get _billing => AppServices.billing;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (!_billing.canBuy) _billing.refresh();
  }

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await _billing.buy();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuyResult.purchased:
        _done('정식 버전이 열렸어요');
      case BuyResult.pending:
        setState(() => _message = '결제 승인을 기다리고 있어요. 승인되면 자동으로 열려요.');
      case BuyResult.canceled:
        break; // 화면에 그대로 머문다 (docs/03 S6)
      case BuyResult.failed:
        setState(
          () => _message = '결제하지 못했어요. ${_billing.lastError ?? ''}'.trim(),
        );
      case BuyResult.unavailable:
        setState(() => _message = '인터넷에 연결한 뒤 다시 시도해 주세요');
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    await _billing.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (AppServices.entitlement.value.isFull) {
      _done('구매를 복원했어요');
    } else {
      setState(() => _message = '복원할 구매 내역이 없어요');
    }
  }

  void _done(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _billing,
      builder: (context, _) {
        final price = _billing.price;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '닫기',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          body: AuroraBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const SizedBox(height: 8),
                  const Center(child: AppIconMark(size: 104)),
                  const SizedBox(height: 20),
                  Text(
                    'Fitness Timer 정식 버전',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '한 번 구매로 평생 사용',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  GlassPanel(
                    blur: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: const [
                        ListTile(
                          leading: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                          title: Text('내 루틴 무제한 만들기·실행'),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                          title: Text('횟수 모드·템포 직접 설정'),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                          title: Text('광고 없음, 구독 없음'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    // 주요 버튼은 거의 불투명한 흰색 (docs/04 1장)
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: const Color(0xFF14161F),
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    // 가격은 Google Play에서 받아온 현지 가격 (docs/03 S6)
                    onPressed: _busy || !_billing.canBuy ? null : _buy,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            price == null ? '구매하기' : '$price 구매하기',
                            style: const TextStyle(fontSize: 17),
                          ),
                  ),
                  if (!_billing.canBuy && !_busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _billing.storeAvailable
                            ? '상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'
                            : '인터넷에 연결한 뒤 다시 시도해 주세요',
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _restore,
                    child: const Text('구매 복원'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '프리셋 4개(타바타, HIIT, 플랭크, 근력 세트)는\n구매하지 않아도 계속 무료로 쓸 수 있어요.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
