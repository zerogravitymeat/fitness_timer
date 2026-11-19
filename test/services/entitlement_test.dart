import 'dart:io';

import 'package:fitness_timer/models/entitlement.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/billing/entitlement_service.dart';
import 'package:fitness_timer/services/billing/trial_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mine = Routine(id: 'mine', name: '하체');

  group('Entitlement (docs/02 10장)', () {
    test('체험 중: 모든 기능', () {
      const e = Entitlement(isFull: false, freeUsed: 14);
      expect((e.inTrial, e.trialEnded, e.freeRemaining), (true, false, 1));
      expect(e.canStart(mine), isTrue);
      expect(e.canUseCustom, isTrue);
    });

    test('체험 종료: 프리셋만 무료, 내 루틴 잠김', () {
      const e = Entitlement(isFull: false, freeUsed: 15);
      expect(e.trialEnded, isTrue);
      expect(e.canUseCustom, isFalse);
      expect(e.canStart(mine), isFalse);
      for (final p in Presets.all) {
        expect(e.canStart(p), isTrue, reason: p.name);
      }
    });

    test('정식 버전: 제한 없음, 체험 안내 없음', () {
      const e = Entitlement(isFull: true, freeUsed: 99);
      expect((e.inTrial, e.trialEnded, e.canStart(mine)), (false, false, true));
      expect(e.noticeAfterRun(usedBefore: 98), isNull);
    });

    test('사용 횟수가 기준보다 많아도 남은 횟수는 0', () {
      expect(const Entitlement(isFull: false, freeUsed: 40).freeRemaining, 0);
    });

    test('결과 화면 안내: 이번 운동이 차감됐을 때만, 5·3·1회 남았을 때와 끝났을 때', () {
      TrialNotice? after(int before) => Entitlement(
        isFull: false,
        freeUsed: before + 1,
      ).noticeAfterRun(usedBefore: before);
      expect(after(9), TrialNotice.remaining); // 5회 남음
      expect(after(10), isNull); // 4회 남음
      expect(after(11), TrialNotice.remaining); // 3회
      expect(after(13), TrialNotice.remaining); // 1회
      expect(after(14), TrialNotice.ended); // 0회
      // 60초 전에 끝내서 차감되지 않은 운동
      expect(
        const Entitlement(
          isFull: false,
          freeUsed: 10,
        ).noticeAfterRun(usedBefore: 10),
        isNull,
      );
    });
  });

  group('저장', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('ent_test'));
    tearDown(() => dir.delete(recursive: true));

    test('TrialStore: 동시에 여러 번 차감해도 빠지지 않는다', () async {
      final t = TrialStore(dir.path);
      await Future.wait([t.increment(), t.increment(), t.increment()]);
      expect(await t.read(), 3);
    });

    test('서비스가 차감한 값을 화면 쪽이 다시 읽는다', () async {
      final ent = EntitlementService(dir.path);
      await ent.load();
      ent.markRunStart();
      await TrialStore(dir.path).increment(); // 서비스 isolate에서 쓴 것과 같음
      await ent.refreshTrial();
      expect(ent.value.freeUsed, 1);
    });

    test('구매 상태는 저장되어 오프라인에서도 유지', () async {
      final a = EntitlementService(dir.path);
      await a.load();
      await a.setFull(true);
      final b = EntitlementService(dir.path);
      await b.load();
      expect(b.value.isFull, isTrue);
      await b.setFull(false); // 환불
      final c = EntitlementService(dir.path);
      await c.load();
      expect(c.value.isFull, isFalse);
    });
  });
}
