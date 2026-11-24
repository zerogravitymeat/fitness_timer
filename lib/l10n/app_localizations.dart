import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @discard.
  ///
  /// In ko, this message translates to:
  /// **'버리기'**
  String get discard;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @saveAndStart.
  ///
  /// In ko, this message translates to:
  /// **'저장 후 시작'**
  String get saveAndStart;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @start.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get start;

  /// No description provided for @edit.
  ///
  /// In ko, this message translates to:
  /// **'수정'**
  String get edit;

  /// No description provided for @copyAndEdit.
  ///
  /// In ko, this message translates to:
  /// **'복사해서 수정'**
  String get copyAndEdit;

  /// No description provided for @done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get done;

  /// No description provided for @goHome.
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get goHome;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @add.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get add;

  /// No description provided for @name.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해 주세요'**
  String get nameRequired;

  /// No description provided for @discardChangesTitle.
  ///
  /// In ko, this message translates to:
  /// **'변경 사항을 버릴까요?'**
  String get discardChangesTitle;

  /// No description provided for @keepEditing.
  ///
  /// In ko, this message translates to:
  /// **'계속 편집'**
  String get keepEditing;

  /// No description provided for @dragToMove.
  ///
  /// In ko, this message translates to:
  /// **'끌어서 옮기기'**
  String get dragToMove;

  /// No description provided for @none.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get none;

  /// No description provided for @custom.
  ///
  /// In ko, this message translates to:
  /// **'직접'**
  String get custom;

  /// No description provided for @customWith.
  ///
  /// In ko, this message translates to:
  /// **'직접 · {value}'**
  String customWith(String value);

  /// No description provided for @routine.
  ///
  /// In ko, this message translates to:
  /// **'루틴'**
  String get routine;

  /// No description provided for @myRoutines.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴'**
  String get myRoutines;

  /// No description provided for @presets.
  ///
  /// In ko, this message translates to:
  /// **'프리셋'**
  String get presets;

  /// No description provided for @courses.
  ///
  /// In ko, this message translates to:
  /// **'코스'**
  String get courses;

  /// No description provided for @newRoutine.
  ///
  /// In ko, this message translates to:
  /// **'새 루틴'**
  String get newRoutine;

  /// No description provided for @newCourse.
  ///
  /// In ko, this message translates to:
  /// **'새 코스'**
  String get newCourse;

  /// No description provided for @addRoutine.
  ///
  /// In ko, this message translates to:
  /// **'루틴 추가'**
  String get addRoutine;

  /// No description provided for @copyName.
  ///
  /// In ko, this message translates to:
  /// **'{name} 복사'**
  String copyName(String name);

  /// No description provided for @defaultRoutineName.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴'**
  String get defaultRoutineName;

  /// No description provided for @defaultCourseName.
  ///
  /// In ko, this message translates to:
  /// **'내 코스'**
  String get defaultCourseName;

  /// No description provided for @timerStartFailed.
  ///
  /// In ko, this message translates to:
  /// **'타이머를 시작하지 못했어요'**
  String get timerStartFailed;

  /// No description provided for @connectInternet.
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결한 뒤 다시 시도해 주세요'**
  String get connectInternet;

  /// No description provided for @restorePurchase.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get restorePurchase;

  /// No description provided for @purchaseRestored.
  ///
  /// In ko, this message translates to:
  /// **'구매를 복원했어요'**
  String get purchaseRestored;

  /// No description provided for @noPurchaseToRestore.
  ///
  /// In ko, this message translates to:
  /// **'복원할 구매 내역이 없어요'**
  String get noPurchaseToRestore;

  /// No description provided for @viewFullVersion.
  ///
  /// In ko, this message translates to:
  /// **'정식 버전 보기'**
  String get viewFullVersion;

  /// No description provided for @freeRemaining.
  ///
  /// In ko, this message translates to:
  /// **'무료 운동 {count}회 남음'**
  String freeRemaining(int count);

  /// No description provided for @durationSeconds.
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초'**
  String durationSeconds(int seconds);

  /// No description provided for @durationMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분'**
  String durationMinutes(int minutes);

  /// No description provided for @durationMinutesSeconds.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 {seconds}초'**
  String durationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @tempoSeconds.
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초'**
  String tempoSeconds(String seconds);

  /// No description provided for @estimateAbout.
  ///
  /// In ko, this message translates to:
  /// **'약 {minutes}분'**
  String estimateAbout(int minutes);

  /// No description provided for @repsCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}회'**
  String repsCount(int count);

  /// No description provided for @summaryReps.
  ///
  /// In ko, this message translates to:
  /// **'{reps}회 × {sets}세트 · {tempo}'**
  String summaryReps(int reps, int sets, String tempo);

  /// No description provided for @summaryWithSets.
  ///
  /// In ko, this message translates to:
  /// **'{base} × {sets}세트'**
  String summaryWithSets(String base, int sets);

  /// No description provided for @courseNoRoutines.
  ///
  /// In ko, this message translates to:
  /// **'루틴 없음'**
  String get courseNoRoutines;

  /// No description provided for @courseSummary.
  ///
  /// In ko, this message translates to:
  /// **'루틴 {count}개 · {estimate}'**
  String courseSummary(int count, String estimate);

  /// No description provided for @segmentPrep.
  ///
  /// In ko, this message translates to:
  /// **'준비'**
  String get segmentPrep;

  /// No description provided for @segmentWork.
  ///
  /// In ko, this message translates to:
  /// **'운동'**
  String get segmentWork;

  /// No description provided for @segmentRest.
  ///
  /// In ko, this message translates to:
  /// **'휴식'**
  String get segmentRest;

  /// No description provided for @segmentSetRest.
  ///
  /// In ko, this message translates to:
  /// **'세트 간 휴식'**
  String get segmentSetRest;

  /// No description provided for @progressCourseRest.
  ///
  /// In ko, this message translates to:
  /// **'루틴 {done}/{total} 완료'**
  String progressCourseRest(int done, int total);

  /// No description provided for @progressSet.
  ///
  /// In ko, this message translates to:
  /// **'세트 {current}/{total}'**
  String progressSet(int current, int total);

  /// No description provided for @progressRound.
  ///
  /// In ko, this message translates to:
  /// **'라운드 {current}/{total}'**
  String progressRound(int current, int total);

  /// No description provided for @progressRoundAndSet.
  ///
  /// In ko, this message translates to:
  /// **'{round} · 세트 {current}/{total}'**
  String progressRoundAndSet(String round, int current, int total);

  /// No description provided for @nextDone.
  ///
  /// In ko, this message translates to:
  /// **'다음: 완료'**
  String get nextDone;

  /// No description provided for @nextItem.
  ///
  /// In ko, this message translates to:
  /// **'다음: {item}'**
  String nextItem(String item);

  /// No description provided for @pause.
  ///
  /// In ko, this message translates to:
  /// **'일시정지'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In ko, this message translates to:
  /// **'재개'**
  String get resume;

  /// No description provided for @next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get previous;

  /// No description provided for @pausedTitle.
  ///
  /// In ko, this message translates to:
  /// **'일시정지 · {title}'**
  String pausedTitle(String title);

  /// No description provided for @repProgress.
  ///
  /// In ko, this message translates to:
  /// **'{segment} {current}/{total}회'**
  String repProgress(String segment, int current, int total);

  /// No description provided for @notificationChannelName.
  ///
  /// In ko, this message translates to:
  /// **'운동 진행'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In ko, this message translates to:
  /// **'운동 타이머가 진행 중일 때 표시됩니다'**
  String get notificationChannelDescription;

  /// No description provided for @notificationStarting.
  ///
  /// In ko, this message translates to:
  /// **'시작하는 중'**
  String get notificationStarting;

  /// No description provided for @interruptedTitle.
  ///
  /// In ko, this message translates to:
  /// **'운동이 중간에 멈췄어요'**
  String get interruptedTitle;

  /// No description provided for @resumeQuestion.
  ///
  /// In ko, this message translates to:
  /// **'멈춘 곳부터 이어서 할까요?'**
  String get resumeQuestion;

  /// No description provided for @batteryHint.
  ///
  /// In ko, this message translates to:
  /// **'휴대폰의 배터리 최적화 때문에 멈췄을 수 있어요. 배터리 설정에서 이 앱을 \"제한 없음\"으로 바꾸면 화면이 꺼져도 끊기지 않아요.'**
  String get batteryHint;

  /// No description provided for @openBatterySettings.
  ///
  /// In ko, this message translates to:
  /// **'배터리 설정 열기'**
  String get openBatterySettings;

  /// No description provided for @restartFromBeginning.
  ///
  /// In ko, this message translates to:
  /// **'처음부터'**
  String get restartFromBeginning;

  /// No description provided for @resumeWorkout.
  ///
  /// In ko, this message translates to:
  /// **'이어서 하기'**
  String get resumeWorkout;

  /// No description provided for @courseEmptySnack.
  ///
  /// In ko, this message translates to:
  /// **'코스에 루틴이 없어요. 수정해서 루틴을 넣어 주세요'**
  String get courseEmptySnack;

  /// No description provided for @deleteRoutineTitle.
  ///
  /// In ko, this message translates to:
  /// **'\"{name}\"을(를) 삭제할까요?'**
  String deleteRoutineTitle(String name);

  /// No description provided for @deleteRoutineInCourses.
  ///
  /// In ko, this message translates to:
  /// **'이 루틴이 들어간 코스 {count}개에서도 빠져요.'**
  String deleteRoutineInCourses(int count);

  /// No description provided for @newRoutineSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'운동 방식과 시간·횟수를 정해 만들어요'**
  String get newRoutineSubtitle;

  /// No description provided for @newCourseSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴을 골라 이어서 하는 묶음을 만들어요'**
  String get newCourseSubtitle;

  /// No description provided for @newCourseNeedsRoutine.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴을 먼저 만들어 주세요'**
  String get newCourseNeedsRoutine;

  /// No description provided for @deleteCourseTitle.
  ///
  /// In ko, this message translates to:
  /// **'\"{name}\" 코스를 삭제할까요?'**
  String deleteCourseTitle(String name);

  /// No description provided for @deleteCourseBody.
  ///
  /// In ko, this message translates to:
  /// **'코스에 들어 있던 루틴은 지워지지 않아요.'**
  String get deleteCourseBody;

  /// No description provided for @favoriteAdd.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 추가'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 해제'**
  String get favoriteRemove;

  /// No description provided for @reorderTitle.
  ///
  /// In ko, this message translates to:
  /// **'순서 편집'**
  String get reorderTitle;

  /// No description provided for @reorderHint.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽 손잡이(≡)를 끌거나 항목을 길게 눌러 옮기세요. 같은 묶음 안에서만 옮길 수 있어요'**
  String get reorderHint;

  /// No description provided for @sortCustom.
  ///
  /// In ko, this message translates to:
  /// **'직접 정렬'**
  String get sortCustom;

  /// No description provided for @sortRecent.
  ///
  /// In ko, this message translates to:
  /// **'최근 사용순'**
  String get sortRecent;

  /// No description provided for @sortName.
  ///
  /// In ko, this message translates to:
  /// **'이름순'**
  String get sortName;

  /// No description provided for @sortCreated.
  ///
  /// In ko, this message translates to:
  /// **'만든 순'**
  String get sortCreated;

  /// No description provided for @recent.
  ///
  /// In ko, this message translates to:
  /// **'최근'**
  String get recent;

  /// No description provided for @favorites.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기'**
  String get favorites;

  /// No description provided for @courseEmptyNoRoutines.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴을 먼저 만들면, 그 루틴들을 골라 코스로 묶을 수 있어요.'**
  String get courseEmptyNoRoutines;

  /// No description provided for @courseEmptyHint.
  ///
  /// In ko, this message translates to:
  /// **'아래 \"추가\" 버튼으로 내 루틴을 골라 이어서 하는 코스를 만들어 보세요. 루틴 사이 휴식도 정할 수 있어요.'**
  String get courseEmptyHint;

  /// No description provided for @routinesEmpty.
  ///
  /// In ko, this message translates to:
  /// **'자주 하는 운동을 루틴으로 저장해 보세요'**
  String get routinesEmpty;

  /// No description provided for @createRoutine.
  ///
  /// In ko, this message translates to:
  /// **'루틴 만들기'**
  String get createRoutine;

  /// No description provided for @startNamed.
  ///
  /// In ko, this message translates to:
  /// **'{name} 시작'**
  String startNamed(String name);

  /// No description provided for @lockedNamed.
  ///
  /// In ko, this message translates to:
  /// **'{name} 잠김, 정식 버전에서 사용'**
  String lockedNamed(String name);

  /// No description provided for @switchToRepsTitle.
  ///
  /// In ko, this message translates to:
  /// **'세트 반복 설정이 사라집니다'**
  String get switchToRepsTitle;

  /// No description provided for @switchToRepsBody.
  ///
  /// In ko, this message translates to:
  /// **'횟수 모드는 라운드를 \"세트\"로 쓰고, 바깥 세트 반복은 쓰지 않아요.'**
  String get switchToRepsBody;

  /// No description provided for @switchAction.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get switchAction;

  /// No description provided for @editRoutine.
  ///
  /// In ko, this message translates to:
  /// **'루틴 편집'**
  String get editRoutine;

  /// No description provided for @workoutMode.
  ///
  /// In ko, this message translates to:
  /// **'운동 방식'**
  String get workoutMode;

  /// No description provided for @modeTime.
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get modeTime;

  /// No description provided for @modeReps.
  ///
  /// In ko, this message translates to:
  /// **'횟수'**
  String get modeReps;

  /// No description provided for @targetReps.
  ///
  /// In ko, this message translates to:
  /// **'목표 횟수'**
  String get targetReps;

  /// No description provided for @sets.
  ///
  /// In ko, this message translates to:
  /// **'세트'**
  String get sets;

  /// No description provided for @rounds.
  ///
  /// In ko, this message translates to:
  /// **'라운드'**
  String get rounds;

  /// No description provided for @moreOptions.
  ///
  /// In ko, this message translates to:
  /// **'더 보기'**
  String get moreOptions;

  /// No description provided for @skipLastSetRest.
  ///
  /// In ko, this message translates to:
  /// **'마지막 세트 휴식 건너뛰기'**
  String get skipLastSetRest;

  /// No description provided for @skipLastRoundRest.
  ///
  /// In ko, this message translates to:
  /// **'마지막 라운드 휴식 건너뛰기'**
  String get skipLastRoundRest;

  /// No description provided for @cueStyleTitle.
  ///
  /// In ko, this message translates to:
  /// **'음성 안내 방식'**
  String get cueStyleTitle;

  /// No description provided for @cueNumbersOnly.
  ///
  /// In ko, this message translates to:
  /// **'숫자만'**
  String get cueNumbersOnly;

  /// No description provided for @cueActionAndNumbers.
  ///
  /// In ko, this message translates to:
  /// **'동작 + 숫자'**
  String get cueActionAndNumbers;

  /// No description provided for @cueActionAndNumbersDisabled.
  ///
  /// In ko, this message translates to:
  /// **'동작 + 숫자 (1회 2.5초 이상)'**
  String get cueActionAndNumbersDisabled;

  /// No description provided for @cueBeepOnly.
  ///
  /// In ko, this message translates to:
  /// **'비프만'**
  String get cueBeepOnly;

  /// No description provided for @estimatedTime.
  ///
  /// In ko, this message translates to:
  /// **'예상 시간 {time}'**
  String estimatedTime(String time);

  /// No description provided for @tempoSlow.
  ///
  /// In ko, this message translates to:
  /// **'천천히'**
  String get tempoSlow;

  /// No description provided for @tempoNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get tempoNormal;

  /// No description provided for @tempoFast.
  ///
  /// In ko, this message translates to:
  /// **'빠르게'**
  String get tempoFast;

  /// No description provided for @tempoTitle.
  ///
  /// In ko, this message translates to:
  /// **'템포 (내려가기-멈춤-올라오기)'**
  String get tempoTitle;

  /// No description provided for @phaseDown.
  ///
  /// In ko, this message translates to:
  /// **'내려가기'**
  String get phaseDown;

  /// No description provided for @phaseHold.
  ///
  /// In ko, this message translates to:
  /// **'멈춤'**
  String get phaseHold;

  /// No description provided for @phaseUp.
  ///
  /// In ko, this message translates to:
  /// **'올라오기'**
  String get phaseUp;

  /// No description provided for @decreaseNamed.
  ///
  /// In ko, this message translates to:
  /// **'{label} 줄이기'**
  String decreaseNamed(String label);

  /// No description provided for @increaseNamed.
  ///
  /// In ko, this message translates to:
  /// **'{label} 늘리기'**
  String increaseNamed(String label);

  /// No description provided for @stopConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'운동을 끝낼까요?'**
  String get stopConfirmTitle;

  /// No description provided for @keepGoing.
  ///
  /// In ko, this message translates to:
  /// **'계속하기'**
  String get keepGoing;

  /// No description provided for @stopAction.
  ///
  /// In ko, this message translates to:
  /// **'끝내기'**
  String get stopAction;

  /// No description provided for @nextCoursePosition.
  ///
  /// In ko, this message translates to:
  /// **'다음 {position}'**
  String nextCoursePosition(String position);

  /// No description provided for @totalRemaining.
  ///
  /// In ko, this message translates to:
  /// **'전체 {time}'**
  String totalRemaining(String time);

  /// No description provided for @plusTenSeconds.
  ///
  /// In ko, this message translates to:
  /// **'+10초'**
  String get plusTenSeconds;

  /// No description provided for @setDone.
  ///
  /// In ko, this message translates to:
  /// **'세트 완료'**
  String get setDone;

  /// No description provided for @endWorkout.
  ///
  /// In ko, this message translates to:
  /// **'운동 끝내기'**
  String get endWorkout;

  /// No description provided for @workoutComplete.
  ///
  /// In ko, this message translates to:
  /// **'운동 완료!'**
  String get workoutComplete;

  /// No description provided for @workoutStopped.
  ///
  /// In ko, this message translates to:
  /// **'운동 종료'**
  String get workoutStopped;

  /// No description provided for @totalTime.
  ///
  /// In ko, this message translates to:
  /// **'총 시간'**
  String get totalTime;

  /// No description provided for @routinesDone.
  ///
  /// In ko, this message translates to:
  /// **'완료한 루틴'**
  String get routinesDone;

  /// No description provided for @setsDone.
  ///
  /// In ko, this message translates to:
  /// **'완료한 세트'**
  String get setsDone;

  /// No description provided for @progress.
  ///
  /// In ko, this message translates to:
  /// **'진행'**
  String get progress;

  /// No description provided for @freeRemainingResult.
  ///
  /// In ko, this message translates to:
  /// **'무료 운동 {count}회 남았어요 · 정식 버전 보기'**
  String freeRemainingResult(int count);

  /// No description provided for @trialUsedUp.
  ///
  /// In ko, this message translates to:
  /// **'무료 체험을 모두 사용했어요'**
  String get trialUsedUp;

  /// No description provided for @trialUsedUpBody.
  ///
  /// In ko, this message translates to:
  /// **'프리셋 4개는 계속 무료예요.\n내 루틴은 정식 버전에서 쓸 수 있어요.'**
  String get trialUsedUpBody;

  /// No description provided for @editCourse.
  ///
  /// In ko, this message translates to:
  /// **'코스 편집'**
  String get editCourse;

  /// No description provided for @routineOrder.
  ///
  /// In ko, this message translates to:
  /// **'루틴 순서'**
  String get routineOrder;

  /// No description provided for @courseOrderHintEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아래 버튼으로 이어서 할 루틴을 넣으세요'**
  String get courseOrderHintEmpty;

  /// No description provided for @courseOrderHint.
  ///
  /// In ko, this message translates to:
  /// **'손잡이(≡)를 끌어 순서를 바꾸고, 사이의 휴식을 눌러 바꾸세요'**
  String get courseOrderHint;

  /// No description provided for @deletedRoutine.
  ///
  /// In ko, this message translates to:
  /// **'지워진 루틴'**
  String get deletedRoutine;

  /// No description provided for @removeNamed.
  ///
  /// In ko, this message translates to:
  /// **'{name} 빼기'**
  String removeNamed(String name);

  /// No description provided for @maxSteps.
  ///
  /// In ko, this message translates to:
  /// **'최대 {count}개까지 넣을 수 있어요'**
  String maxSteps(int count);

  /// No description provided for @needOneRoutine.
  ///
  /// In ko, this message translates to:
  /// **'루틴을 1개 이상 넣어 주세요'**
  String get needOneRoutine;

  /// No description provided for @noRest.
  ///
  /// In ko, this message translates to:
  /// **'휴식 없이 바로'**
  String get noRest;

  /// No description provided for @restWith.
  ///
  /// In ko, this message translates to:
  /// **'휴식 {time}'**
  String restWith(String time);

  /// No description provided for @changeCourseRest.
  ///
  /// In ko, this message translates to:
  /// **'루틴 사이 휴식 바꾸기'**
  String get changeCourseRest;

  /// No description provided for @courseRest.
  ///
  /// In ko, this message translates to:
  /// **'루틴 사이 휴식'**
  String get courseRest;

  /// No description provided for @courseRestNoneHint.
  ///
  /// In ko, this message translates to:
  /// **'\"없음\"이면 앞 루틴이 끝나자마자 다음 루틴을 시작해요'**
  String get courseRestNoneHint;

  /// No description provided for @noMyRoutines.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴이 없어요. 홈에서 루틴을 먼저 만들어 주세요.'**
  String get noMyRoutines;

  /// No description provided for @fullVersionUnlocked.
  ///
  /// In ko, this message translates to:
  /// **'정식 버전이 열렸어요'**
  String get fullVersionUnlocked;

  /// No description provided for @purchasePending.
  ///
  /// In ko, this message translates to:
  /// **'결제 승인을 기다리고 있어요. 승인되면 자동으로 열려요.'**
  String get purchasePending;

  /// No description provided for @purchaseFailed.
  ///
  /// In ko, this message translates to:
  /// **'결제하지 못했어요.'**
  String get purchaseFailed;

  /// No description provided for @paywallTitle.
  ///
  /// In ko, this message translates to:
  /// **'Fitness Timer 정식 버전'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'한 번 구매로 평생 사용'**
  String get paywallSubtitle;

  /// No description provided for @benefitUnlimited.
  ///
  /// In ko, this message translates to:
  /// **'내 루틴 무제한 만들기·실행'**
  String get benefitUnlimited;

  /// No description provided for @benefitReps.
  ///
  /// In ko, this message translates to:
  /// **'횟수 모드·템포 직접 설정'**
  String get benefitReps;

  /// No description provided for @benefitNoAds.
  ///
  /// In ko, this message translates to:
  /// **'광고 없음, 구독 없음'**
  String get benefitNoAds;

  /// No description provided for @buy.
  ///
  /// In ko, this message translates to:
  /// **'구매하기'**
  String get buy;

  /// No description provided for @buyWithPrice.
  ///
  /// In ko, this message translates to:
  /// **'{price} 구매하기'**
  String buyWithPrice(String price);

  /// No description provided for @productLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'**
  String get productLoadFailed;

  /// No description provided for @presetsFreeNote.
  ///
  /// In ko, this message translates to:
  /// **'프리셋 4개(타바타, HIIT, 플랭크, 근력 세트)는\n구매하지 않아도 계속 무료로 쓸 수 있어요.'**
  String get presetsFreeNote;

  /// No description provided for @ttsPreviewText.
  ///
  /// In ko, this message translates to:
  /// **'휴식 10초 남았습니다'**
  String get ttsPreviewText;

  /// No description provided for @alerts.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get alerts;

  /// No description provided for @sound.
  ///
  /// In ko, this message translates to:
  /// **'소리'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In ko, this message translates to:
  /// **'진동'**
  String get vibration;

  /// No description provided for @voiceGuide.
  ///
  /// In ko, this message translates to:
  /// **'음성 안내'**
  String get voiceGuide;

  /// No description provided for @countdownBeforeEnd.
  ///
  /// In ko, this message translates to:
  /// **'종료 전 카운트다운'**
  String get countdownBeforeEnd;

  /// No description provided for @speechSpeed.
  ///
  /// In ko, this message translates to:
  /// **'음성 속도'**
  String get speechSpeed;

  /// No description provided for @speedSlow.
  ///
  /// In ko, this message translates to:
  /// **'느리게'**
  String get speedSlow;

  /// No description provided for @speedNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get speedNormal;

  /// No description provided for @speedFast.
  ///
  /// In ko, this message translates to:
  /// **'빠르게'**
  String get speedFast;

  /// No description provided for @previewVoice.
  ///
  /// In ko, this message translates to:
  /// **'미리 듣기'**
  String get previewVoice;

  /// No description provided for @voiceData.
  ///
  /// In ko, this message translates to:
  /// **'한국어 음성'**
  String get voiceData;

  /// No description provided for @voiceChoice.
  ///
  /// In ko, this message translates to:
  /// **'목소리'**
  String get voiceChoice;

  /// No description provided for @voiceDefault.
  ///
  /// In ko, this message translates to:
  /// **'기본'**
  String get voiceDefault;

  /// No description provided for @voiceNumber.
  ///
  /// In ko, this message translates to:
  /// **'음성 {number}'**
  String voiceNumber(int number);

  /// No description provided for @checking.
  ///
  /// In ko, this message translates to:
  /// **'확인 중…'**
  String get checking;

  /// No description provided for @available.
  ///
  /// In ko, this message translates to:
  /// **'사용 가능'**
  String get available;

  /// No description provided for @voiceMissing.
  ///
  /// In ko, this message translates to:
  /// **'설치 필요. 설치 전에는 비프음과 진동으로만 안내해요.'**
  String get voiceMissing;

  /// No description provided for @openTtsSettings.
  ///
  /// In ko, this message translates to:
  /// **'TTS 설정 열기'**
  String get openTtsSettings;

  /// No description provided for @screen.
  ///
  /// In ko, this message translates to:
  /// **'화면'**
  String get screen;

  /// No description provided for @keepScreenOn.
  ///
  /// In ko, this message translates to:
  /// **'운동 중 화면 꺼짐 방지'**
  String get keepScreenOn;

  /// No description provided for @other.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get other;

  /// No description provided for @openSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get openSourceLicenses;

  /// No description provided for @fullVersion.
  ///
  /// In ko, this message translates to:
  /// **'정식 버전'**
  String get fullVersion;

  /// No description provided for @status.
  ///
  /// In ko, this message translates to:
  /// **'상태'**
  String get status;

  /// No description provided for @fullVersionActive.
  ///
  /// In ko, this message translates to:
  /// **'정식 버전 사용 중'**
  String get fullVersionActive;

  /// No description provided for @trialEnded.
  ///
  /// In ko, this message translates to:
  /// **'체험 종료 (프리셋은 계속 무료)'**
  String get trialEnded;

  /// No description provided for @buyFullVersion.
  ///
  /// In ko, this message translates to:
  /// **'정식 버전 구매'**
  String get buyFullVersion;

  /// No description provided for @presetTabata.
  ///
  /// In ko, this message translates to:
  /// **'타바타'**
  String get presetTabata;

  /// No description provided for @presetHiit.
  ///
  /// In ko, this message translates to:
  /// **'HIIT'**
  String get presetHiit;

  /// No description provided for @presetPlank.
  ///
  /// In ko, this message translates to:
  /// **'플랭크'**
  String get presetPlank;

  /// No description provided for @presetStrength.
  ///
  /// In ko, this message translates to:
  /// **'근력 세트'**
  String get presetStrength;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'기기 언어 따르기'**
  String get languageSystem;

  /// No description provided for @autoFillDefaults.
  ///
  /// In ko, this message translates to:
  /// **'{name} 기본값으로 맞췄어요'**
  String autoFillDefaults(String name);

  /// No description provided for @autoFillCopied.
  ///
  /// In ko, this message translates to:
  /// **'\"{name}\" 설정을 가져왔어요'**
  String autoFillCopied(String name);

  /// No description provided for @undo.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get undo;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
