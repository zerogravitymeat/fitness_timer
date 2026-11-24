// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get discard => '버리기';

  @override
  String get save => '저장';

  @override
  String get saveAndStart => '저장 후 시작';

  @override
  String get confirm => '확인';

  @override
  String get start => '시작';

  @override
  String get edit => '수정';

  @override
  String get copyAndEdit => '복사해서 수정';

  @override
  String get done => '완료';

  @override
  String get goHome => '홈으로';

  @override
  String get settings => '설정';

  @override
  String get close => '닫기';

  @override
  String get add => '추가';

  @override
  String get name => '이름';

  @override
  String get nameRequired => '이름을 입력해 주세요';

  @override
  String get discardChangesTitle => '변경 사항을 버릴까요?';

  @override
  String get keepEditing => '계속 편집';

  @override
  String get dragToMove => '끌어서 옮기기';

  @override
  String get none => '없음';

  @override
  String get custom => '직접';

  @override
  String customWith(String value) {
    return '직접 · $value';
  }

  @override
  String get routine => '루틴';

  @override
  String get myRoutines => '내 루틴';

  @override
  String get presets => '프리셋';

  @override
  String get courses => '코스';

  @override
  String get newRoutine => '새 루틴';

  @override
  String get newCourse => '새 코스';

  @override
  String get addRoutine => '루틴 추가';

  @override
  String copyName(String name) {
    return '$name 복사';
  }

  @override
  String get defaultRoutineName => '내 루틴';

  @override
  String get defaultCourseName => '내 코스';

  @override
  String get timerStartFailed => '타이머를 시작하지 못했어요';

  @override
  String get connectInternet => '인터넷에 연결한 뒤 다시 시도해 주세요';

  @override
  String get restorePurchase => '구매 복원';

  @override
  String get purchaseRestored => '구매를 복원했어요';

  @override
  String get noPurchaseToRestore => '복원할 구매 내역이 없어요';

  @override
  String get viewFullVersion => '정식 버전 보기';

  @override
  String freeRemaining(int count) {
    return '무료 운동 $count회 남음';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds초';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String tempoSeconds(String seconds) {
    return '$seconds초';
  }

  @override
  String estimateAbout(int minutes) {
    return '약 $minutes분';
  }

  @override
  String repsCount(int count) {
    return '$count회';
  }

  @override
  String summaryReps(int reps, int sets, String tempo) {
    return '$reps회 × $sets세트 · $tempo';
  }

  @override
  String summaryWithSets(String base, int sets) {
    return '$base × $sets세트';
  }

  @override
  String get courseNoRoutines => '루틴 없음';

  @override
  String courseSummary(int count, String estimate) {
    return '루틴 $count개 · $estimate';
  }

  @override
  String get segmentPrep => '준비';

  @override
  String get segmentWork => '운동';

  @override
  String get segmentRest => '휴식';

  @override
  String get segmentSetRest => '세트 간 휴식';

  @override
  String progressCourseRest(int done, int total) {
    return '루틴 $done/$total 완료';
  }

  @override
  String progressSet(int current, int total) {
    return '세트 $current/$total';
  }

  @override
  String progressRound(int current, int total) {
    return '라운드 $current/$total';
  }

  @override
  String progressRoundAndSet(String round, int current, int total) {
    return '$round · 세트 $current/$total';
  }

  @override
  String get nextDone => '다음: 완료';

  @override
  String nextItem(String item) {
    return '다음: $item';
  }

  @override
  String get pause => '일시정지';

  @override
  String get resume => '재개';

  @override
  String get next => '다음';

  @override
  String get previous => '이전';

  @override
  String pausedTitle(String title) {
    return '일시정지 · $title';
  }

  @override
  String repProgress(String segment, int current, int total) {
    return '$segment $current/$total회';
  }

  @override
  String get notificationChannelName => '운동 진행';

  @override
  String get notificationChannelDescription => '운동 타이머가 진행 중일 때 표시됩니다';

  @override
  String get notificationStarting => '시작하는 중';

  @override
  String get interruptedTitle => '운동이 중간에 멈췄어요';

  @override
  String get resumeQuestion => '멈춘 곳부터 이어서 할까요?';

  @override
  String get batteryHint =>
      '휴대폰의 배터리 최적화 때문에 멈췄을 수 있어요. 배터리 설정에서 이 앱을 \"제한 없음\"으로 바꾸면 화면이 꺼져도 끊기지 않아요.';

  @override
  String get openBatterySettings => '배터리 설정 열기';

  @override
  String get restartFromBeginning => '처음부터';

  @override
  String get resumeWorkout => '이어서 하기';

  @override
  String get courseEmptySnack => '코스에 루틴이 없어요. 수정해서 루틴을 넣어 주세요';

  @override
  String deleteRoutineTitle(String name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String deleteRoutineInCourses(int count) {
    return '이 루틴이 들어간 코스 $count개에서도 빠져요.';
  }

  @override
  String get newRoutineSubtitle => '운동 방식과 시간·횟수를 정해 만들어요';

  @override
  String get newCourseSubtitle => '내 루틴을 골라 이어서 하는 묶음을 만들어요';

  @override
  String get newCourseNeedsRoutine => '내 루틴을 먼저 만들어 주세요';

  @override
  String deleteCourseTitle(String name) {
    return '\"$name\" 코스를 삭제할까요?';
  }

  @override
  String get deleteCourseBody => '코스에 들어 있던 루틴은 지워지지 않아요.';

  @override
  String get favoriteAdd => '즐겨찾기 추가';

  @override
  String get favoriteRemove => '즐겨찾기 해제';

  @override
  String get reorderTitle => '순서 편집';

  @override
  String get reorderHint =>
      '오른쪽 손잡이(≡)를 끌거나 항목을 길게 눌러 옮기세요. 같은 묶음 안에서만 옮길 수 있어요';

  @override
  String get sortCustom => '직접 정렬';

  @override
  String get sortRecent => '최근 사용순';

  @override
  String get sortName => '이름순';

  @override
  String get sortCreated => '만든 순';

  @override
  String get recent => '최근';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get courseEmptyNoRoutines => '내 루틴을 먼저 만들면, 그 루틴들을 골라 코스로 묶을 수 있어요.';

  @override
  String get courseEmptyHint =>
      '아래 \"추가\" 버튼으로 내 루틴을 골라 이어서 하는 코스를 만들어 보세요. 루틴 사이 휴식도 정할 수 있어요.';

  @override
  String get routinesEmpty => '자주 하는 운동을 루틴으로 저장해 보세요';

  @override
  String get createRoutine => '루틴 만들기';

  @override
  String startNamed(String name) {
    return '$name 시작';
  }

  @override
  String lockedNamed(String name) {
    return '$name 잠김, 정식 버전에서 사용';
  }

  @override
  String get switchToRepsTitle => '세트 반복 설정이 사라집니다';

  @override
  String get switchToRepsBody => '횟수 모드는 라운드를 \"세트\"로 쓰고, 바깥 세트 반복은 쓰지 않아요.';

  @override
  String get switchAction => '바꾸기';

  @override
  String get editRoutine => '루틴 편집';

  @override
  String get workoutMode => '운동 방식';

  @override
  String get modeTime => '시간';

  @override
  String get modeReps => '횟수';

  @override
  String get targetReps => '목표 횟수';

  @override
  String get sets => '세트';

  @override
  String get rounds => '라운드';

  @override
  String get moreOptions => '더 보기';

  @override
  String get skipLastSetRest => '마지막 세트 휴식 건너뛰기';

  @override
  String get skipLastRoundRest => '마지막 라운드 휴식 건너뛰기';

  @override
  String get cueStyleTitle => '음성 안내 방식';

  @override
  String get cueNumbersOnly => '숫자만';

  @override
  String get cueActionAndNumbers => '동작 + 숫자';

  @override
  String get cueActionAndNumbersDisabled => '동작 + 숫자 (1회 2.5초 이상)';

  @override
  String get cueBeepOnly => '비프만';

  @override
  String estimatedTime(String time) {
    return '예상 시간 $time';
  }

  @override
  String get tempoSlow => '천천히';

  @override
  String get tempoNormal => '보통';

  @override
  String get tempoFast => '빠르게';

  @override
  String get tempoTitle => '템포 (내려가기-멈춤-올라오기)';

  @override
  String get phaseDown => '내려가기';

  @override
  String get phaseHold => '멈춤';

  @override
  String get phaseUp => '올라오기';

  @override
  String decreaseNamed(String label) {
    return '$label 줄이기';
  }

  @override
  String increaseNamed(String label) {
    return '$label 늘리기';
  }

  @override
  String get stopConfirmTitle => '운동을 끝낼까요?';

  @override
  String get keepGoing => '계속하기';

  @override
  String get stopAction => '끝내기';

  @override
  String nextCoursePosition(String position) {
    return '다음 $position';
  }

  @override
  String totalRemaining(String time) {
    return '전체 $time';
  }

  @override
  String get plusTenSeconds => '+10초';

  @override
  String get setDone => '세트 완료';

  @override
  String get endWorkout => '운동 끝내기';

  @override
  String get workoutComplete => '운동 완료!';

  @override
  String get workoutStopped => '운동 종료';

  @override
  String get totalTime => '총 시간';

  @override
  String get routinesDone => '완료한 루틴';

  @override
  String get setsDone => '완료한 세트';

  @override
  String get progress => '진행';

  @override
  String freeRemainingResult(int count) {
    return '무료 운동 $count회 남았어요 · 정식 버전 보기';
  }

  @override
  String get trialUsedUp => '무료 체험을 모두 사용했어요';

  @override
  String get trialUsedUpBody => '프리셋 4개는 계속 무료예요.\n내 루틴은 정식 버전에서 쓸 수 있어요.';

  @override
  String get editCourse => '코스 편집';

  @override
  String get routineOrder => '루틴 순서';

  @override
  String get courseOrderHintEmpty => '아래 버튼으로 이어서 할 루틴을 넣으세요';

  @override
  String get courseOrderHint => '손잡이(≡)를 끌어 순서를 바꾸고, 사이의 휴식을 눌러 바꾸세요';

  @override
  String get deletedRoutine => '지워진 루틴';

  @override
  String removeNamed(String name) {
    return '$name 빼기';
  }

  @override
  String maxSteps(int count) {
    return '최대 $count개까지 넣을 수 있어요';
  }

  @override
  String get needOneRoutine => '루틴을 1개 이상 넣어 주세요';

  @override
  String get noRest => '휴식 없이 바로';

  @override
  String restWith(String time) {
    return '휴식 $time';
  }

  @override
  String get changeCourseRest => '루틴 사이 휴식 바꾸기';

  @override
  String get courseRest => '루틴 사이 휴식';

  @override
  String get courseRestNoneHint => '\"없음\"이면 앞 루틴이 끝나자마자 다음 루틴을 시작해요';

  @override
  String get noMyRoutines => '내 루틴이 없어요. 홈에서 루틴을 먼저 만들어 주세요.';

  @override
  String get fullVersionUnlocked => '정식 버전이 열렸어요';

  @override
  String get purchasePending => '결제 승인을 기다리고 있어요. 승인되면 자동으로 열려요.';

  @override
  String get purchaseFailed => '결제하지 못했어요.';

  @override
  String get paywallTitle => 'Fitness Timer 정식 버전';

  @override
  String get paywallSubtitle => '한 번 구매로 평생 사용';

  @override
  String get benefitUnlimited => '내 루틴 무제한 만들기·실행';

  @override
  String get benefitReps => '횟수 모드·템포 직접 설정';

  @override
  String get benefitNoAds => '광고 없음, 구독 없음';

  @override
  String get buy => '구매하기';

  @override
  String buyWithPrice(String price) {
    return '$price 구매하기';
  }

  @override
  String get productLoadFailed => '상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get presetsFreeNote =>
      '프리셋 4개(타바타, HIIT, 플랭크, 근력 세트)는\n구매하지 않아도 계속 무료로 쓸 수 있어요.';

  @override
  String get ttsPreviewText => '휴식 10초 남았습니다';

  @override
  String get alerts => '알림';

  @override
  String get sound => '소리';

  @override
  String get vibration => '진동';

  @override
  String get voiceGuide => '음성 안내';

  @override
  String get countdownBeforeEnd => '종료 전 카운트다운';

  @override
  String get speechSpeed => '음성 속도';

  @override
  String get speedSlow => '느리게';

  @override
  String get speedNormal => '보통';

  @override
  String get speedFast => '빠르게';

  @override
  String get previewVoice => '미리 듣기';

  @override
  String get voiceData => '한국어 음성';

  @override
  String get voiceChoice => '목소리';

  @override
  String get voiceDefault => '기본';

  @override
  String voiceNumber(int number) {
    return '음성 $number';
  }

  @override
  String get checking => '확인 중…';

  @override
  String get available => '사용 가능';

  @override
  String get voiceMissing => '설치 필요. 설치 전에는 비프음과 진동으로만 안내해요.';

  @override
  String get openTtsSettings => 'TTS 설정 열기';

  @override
  String get screen => '화면';

  @override
  String get keepScreenOn => '운동 중 화면 꺼짐 방지';

  @override
  String get other => '기타';

  @override
  String get openSourceLicenses => '오픈소스 라이선스';

  @override
  String get fullVersion => '정식 버전';

  @override
  String get status => '상태';

  @override
  String get fullVersionActive => '정식 버전 사용 중';

  @override
  String get trialEnded => '체험 종료 (프리셋은 계속 무료)';

  @override
  String get buyFullVersion => '정식 버전 구매';

  @override
  String get presetTabata => '타바타';

  @override
  String get presetHiit => 'HIIT';

  @override
  String get presetPlank => '플랭크';

  @override
  String get presetStrength => '근력 세트';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '기기 언어 따르기';

  @override
  String autoFillDefaults(String name) {
    return '$name 기본값으로 맞췄어요';
  }

  @override
  String autoFillCopied(String name) {
    return '\"$name\" 설정을 가져왔어요';
  }

  @override
  String get undo => '되돌리기';
}
