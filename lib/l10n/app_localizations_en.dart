// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get discard => 'Discard';

  @override
  String get save => 'Save';

  @override
  String get saveAndStart => 'Save and start';

  @override
  String get confirm => 'OK';

  @override
  String get start => 'Start';

  @override
  String get edit => 'Edit';

  @override
  String get copyAndEdit => 'Duplicate and edit';

  @override
  String get done => 'Done';

  @override
  String get goHome => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get dragToMove => 'Drag to move';

  @override
  String get none => 'None';

  @override
  String get custom => 'Custom';

  @override
  String customWith(String value) {
    return 'Custom · $value';
  }

  @override
  String get routine => 'Routine';

  @override
  String get myRoutines => 'My routines';

  @override
  String get courses => 'Courses';

  @override
  String get newRoutine => 'New routine';

  @override
  String get newCourse => 'New course';

  @override
  String get addRoutine => 'Add routine';

  @override
  String copyName(String name) {
    return '$name copy';
  }

  @override
  String get defaultRoutineName => 'My routine';

  @override
  String get defaultCourseName => 'My course';

  @override
  String get timerStartFailed => 'Couldn\'t start the timer';

  @override
  String get connectInternet => 'Connect to the internet and try again';

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get purchaseRestored => 'Purchase restored';

  @override
  String get noPurchaseToRestore => 'No purchase to restore';

  @override
  String get viewFullVersion => 'See full version';

  @override
  String freeRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free workouts left',
      one: '1 free workout left',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes min ${seconds}s';
  }

  @override
  String tempoSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String estimateAbout(int minutes) {
    return 'about $minutes min';
  }

  @override
  String repsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
      one: '1 rep',
    );
    return '$_temp0';
  }

  @override
  String summaryReps(int reps, int sets, String tempo) {
    String _temp0 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '$reps reps × $_temp0 · $tempo';
  }

  @override
  String summaryWithSets(String base, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '$base × $_temp0';
  }

  @override
  String get courseNoRoutines => 'No routines';

  @override
  String courseSummary(int count, String estimate) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routines',
      one: '1 routine',
    );
    return '$_temp0 · $estimate';
  }

  @override
  String get segmentPrep => 'Get ready';

  @override
  String get segmentWork => 'Work';

  @override
  String get segmentRest => 'Rest';

  @override
  String get segmentSetRest => 'Rest between sets';

  @override
  String progressCourseRest(int done, int total) {
    return 'Routine $done/$total done';
  }

  @override
  String progressSet(int current, int total) {
    return 'Set $current/$total';
  }

  @override
  String progressRound(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String progressRoundAndSet(String round, int current, int total) {
    return '$round · Set $current/$total';
  }

  @override
  String get nextDone => 'Next: Done';

  @override
  String nextItem(String item) {
    return 'Next: $item';
  }

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String pausedTitle(String title) {
    return 'Paused · $title';
  }

  @override
  String repProgress(String segment, int current, int total) {
    return '$segment $current/$total reps';
  }

  @override
  String get notificationChannelName => 'Workout in progress';

  @override
  String get notificationChannelDescription =>
      'Shown while the workout timer is running';

  @override
  String get notificationStarting => 'Starting';

  @override
  String get interruptedTitle => 'Your workout was interrupted';

  @override
  String get resumeQuestion => 'Continue from where you stopped?';

  @override
  String get batteryHint =>
      'Your phone\'s battery optimization may have stopped it. Set this app to \"Unrestricted\" in battery settings to keep it running with the screen off.';

  @override
  String get openBatterySettings => 'Open battery settings';

  @override
  String get restartFromBeginning => 'Start over';

  @override
  String get resumeWorkout => 'Continue';

  @override
  String get courseEmptySnack =>
      'This course has no routines. Edit it to add some.';

  @override
  String deleteRoutineTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteRoutineInCourses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It will also be removed from $count courses.',
      one: 'It will also be removed from 1 course.',
    );
    return '$_temp0';
  }

  @override
  String get newRoutineSubtitle => 'Set the workout type, time, and reps';

  @override
  String get newCourseSubtitle => 'Chain your routines to do one after another';

  @override
  String get newCourseNeedsRoutine => 'Create a routine first';

  @override
  String deleteCourseTitle(String name) {
    return 'Delete the course \"$name\"?';
  }

  @override
  String get deleteCourseBody =>
      'The routines in this course won\'t be deleted.';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get reorderTitle => 'Reorder';

  @override
  String get reorderHint =>
      'Drag the handle (≡) on the right or long-press an item to move it. Items move only within their group.';

  @override
  String get sortCustom => 'Custom order';

  @override
  String get sortRecent => 'Recently used';

  @override
  String get sortName => 'Name';

  @override
  String get sortCreated => 'Date created';

  @override
  String get favorites => 'Favorites';

  @override
  String get courseEmptyNoRoutines =>
      'Once you create routines, you can combine them into a course.';

  @override
  String get courseEmptyHint =>
      'Chain your routines into a course. You can set the rest between routines, too.';

  @override
  String get routinesEmpty => 'Save the workouts you do often as routines';

  @override
  String get createRoutine => 'Create routine';

  @override
  String get recentWorkout => 'Recent workout';

  @override
  String get myWorkouts => 'My workouts';

  @override
  String get basicWorkouts => 'Built-in workouts';

  @override
  String get alwaysFree => 'Always free';

  @override
  String get basicWorkoutsFirstTitle =>
      'Start right away with a built-in workout';

  @override
  String get basicWorkoutsFirstBody =>
      'Free to use anytime, no purchase needed';

  @override
  String tabRoutines(int count) {
    return 'Routines $count';
  }

  @override
  String tabCourses(int count) {
    return 'Courses $count';
  }

  @override
  String get sortTooltip => 'Sort';

  @override
  String get createCourse => 'Create course';

  @override
  String get lockedMineBanner => 'Available again in the full version';

  @override
  String get lockedMineAction => 'View';

  @override
  String freeBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free left',
      one: '1 free left',
    );
    return '$_temp0';
  }

  @override
  String get createNew => 'Create';

  @override
  String get copyPreset => 'Copy a built-in workout';

  @override
  String get copyPresetSubtitle => 'Make Tabata, HIIT, and more your own';

  @override
  String get pickPresetToCopy => 'Choose a built-in workout to copy';

  @override
  String startNamed(String name) {
    return 'Start $name';
  }

  @override
  String lockedNamed(String name) {
    return '$name locked, available in the full version';
  }

  @override
  String get switchToRepsTitle => 'Set repeats will be removed';

  @override
  String get switchToRepsBody =>
      'Reps mode uses rounds as \"sets\" and doesn\'t use outer set repeats.';

  @override
  String get switchAction => 'Switch';

  @override
  String get editRoutine => 'Edit routine';

  @override
  String get workoutMode => 'Workout type';

  @override
  String get modeTime => 'Time';

  @override
  String get modeReps => 'Reps';

  @override
  String get targetReps => 'Target reps';

  @override
  String get sets => 'Sets';

  @override
  String get rounds => 'Rounds';

  @override
  String get moreOptions => 'More options';

  @override
  String get skipLastSetRest => 'Skip rest after last set';

  @override
  String get skipLastRoundRest => 'Skip rest after last round';

  @override
  String get cueStyleTitle => 'Voice cues';

  @override
  String get cueNumbersOnly => 'Numbers only';

  @override
  String get cueActionAndNumbers => 'Actions + numbers';

  @override
  String get cueActionAndNumbersDisabled => 'Actions + numbers (2.5s+ per rep)';

  @override
  String get cueBeepOnly => 'Beeps only';

  @override
  String estimatedTime(String time) {
    return 'Estimated time $time';
  }

  @override
  String get tempoSlow => 'Slow';

  @override
  String get tempoNormal => 'Normal';

  @override
  String get tempoFast => 'Fast';

  @override
  String get tempoTitle => 'Tempo (down-hold-up)';

  @override
  String get phaseDown => 'Down';

  @override
  String get phaseHold => 'Hold';

  @override
  String get phaseUp => 'Up';

  @override
  String decreaseNamed(String label) {
    return 'Decrease $label';
  }

  @override
  String increaseNamed(String label) {
    return 'Increase $label';
  }

  @override
  String get stopConfirmTitle => 'End workout?';

  @override
  String get keepGoing => 'Keep going';

  @override
  String get stopAction => 'End';

  @override
  String nextCoursePosition(String position) {
    return 'Next $position';
  }

  @override
  String totalRemaining(String time) {
    return 'Total $time';
  }

  @override
  String get plusTenSeconds => '+10s';

  @override
  String get setDone => 'Set done';

  @override
  String get endWorkout => 'End workout';

  @override
  String get workoutComplete => 'Workout complete!';

  @override
  String get workoutStopped => 'Workout ended';

  @override
  String get totalTime => 'Total time';

  @override
  String get routinesDone => 'Routines done';

  @override
  String get setsDone => 'Sets done';

  @override
  String get progress => 'Progress';

  @override
  String freeRemainingResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free workouts left',
      one: '1 free workout left',
    );
    return '$_temp0 · See full version';
  }

  @override
  String get trialUsedUp => 'You\'ve used all your free workouts';

  @override
  String get trialUsedUpBody =>
      'The 4 built-in workouts stay free.\nYour own routines need the full version.';

  @override
  String get editCourse => 'Edit course';

  @override
  String get routineOrder => 'Routine order';

  @override
  String get courseOrderHintEmpty =>
      'Add routines to do in a row with the button below';

  @override
  String get courseOrderHint =>
      'Drag the handle (≡) to reorder, and tap a rest to change it';

  @override
  String get deletedRoutine => 'Deleted routine';

  @override
  String removeNamed(String name) {
    return 'Remove $name';
  }

  @override
  String maxSteps(int count) {
    return 'You can add up to $count';
  }

  @override
  String get needOneRoutine => 'Add at least 1 routine';

  @override
  String get noRest => 'No rest';

  @override
  String restWith(String time) {
    return 'Rest $time';
  }

  @override
  String get changeCourseRest => 'Change rest between routines';

  @override
  String get courseRest => 'Rest between routines';

  @override
  String get courseRestNoneHint =>
      'With \"None\", the next routine starts right after the previous one';

  @override
  String get noMyRoutines =>
      'You don\'t have any routines. Create one on the home screen first.';

  @override
  String get fullVersionUnlocked => 'Full version unlocked';

  @override
  String get purchasePending =>
      'Waiting for payment approval. It\'ll unlock automatically once approved.';

  @override
  String get purchaseFailed => 'Payment didn\'t go through.';

  @override
  String get paywallTitle => 'Fitness Timer Full Version';

  @override
  String get paywallSubtitle => 'Buy once, use forever';

  @override
  String get benefitUnlimited => 'Create and run unlimited routines';

  @override
  String get benefitReps => 'Reps mode and custom tempo';

  @override
  String get benefitNoAds => 'No ads, no subscription';

  @override
  String get buy => 'Buy';

  @override
  String buyWithPrice(String price) {
    return 'Buy for $price';
  }

  @override
  String get productLoadFailed =>
      'Couldn\'t load product info. Please try again later.';

  @override
  String get presetsFreeNote =>
      'The 4 built-in workouts (Tabata, HIIT, Plank, Strength Sets)\nstay free without a purchase.';

  @override
  String get ttsPreviewText => '10 seconds of rest left';

  @override
  String get alerts => 'Alerts';

  @override
  String get sound => 'Sound';

  @override
  String get vibration => 'Vibration';

  @override
  String get voiceGuide => 'Voice cues';

  @override
  String get countdownBeforeEnd => 'Countdown before end';

  @override
  String get speechSpeed => 'Voice speed';

  @override
  String get speedSlow => 'Slow';

  @override
  String get speedNormal => 'Normal';

  @override
  String get speedFast => 'Fast';

  @override
  String get previewVoice => 'Preview';

  @override
  String get voiceData => 'English voice';

  @override
  String get voiceChoice => 'Voice';

  @override
  String get voiceDefault => 'Default';

  @override
  String voiceNumber(int number) {
    return 'Voice $number';
  }

  @override
  String get checking => 'Checking…';

  @override
  String get available => 'Available';

  @override
  String get voiceMissing =>
      'Needs install. Until then, you\'ll get beeps and vibration only.';

  @override
  String get openTtsSettings => 'Open TTS settings';

  @override
  String get screen => 'Screen';

  @override
  String get keepScreenOn => 'Keep screen on during workout';

  @override
  String get other => 'Other';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get fullVersion => 'Full version';

  @override
  String get status => 'Status';

  @override
  String get fullVersionActive => 'Using full version';

  @override
  String get trialEnded => 'Trial ended (built-in workouts stay free)';

  @override
  String get buyFullVersion => 'Buy full version';

  @override
  String get presetTabata => 'Tabata';

  @override
  String get presetHiit => 'HIIT';

  @override
  String get presetPlank => 'Plank';

  @override
  String get presetStrength => 'Strength Sets';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Use phone language';

  @override
  String autoFillDefaults(String name) {
    return 'Set to $name defaults';
  }

  @override
  String autoFillCopied(String name) {
    return 'Copied settings from \"$name\"';
  }

  @override
  String get undo => 'Undo';
}
