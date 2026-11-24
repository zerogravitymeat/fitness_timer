import 'routine.dart';

/// 운동 하나의 기본 설정. 추천 목록에서 이 운동을 고르면 새 루틴에 채운다.
/// 준비 10초, 마지막 휴식 건너뛰기는 공통이다.
class ExerciseDefaults {
  /// 시간 모드: 운동 [work]초 / 휴식 [rest]초 × [rounds]라운드
  const ExerciseDefaults.time(int work, int rest, this.rounds)
    : endCondition = EndCondition.time,
      workSec = work,
      restSec = rest,
      reps = 12,
      tempo = Tempo.normal;

  /// 횟수 모드: [reps]회 · [tempo] · [sets]세트 · 세트 간 휴식 [rest]초
  const ExerciseDefaults.reps(this.reps, this.tempo, int sets, int rest)
    : endCondition = EndCondition.reps,
      workSec = 40,
      restSec = rest,
      rounds = sets;

  final EndCondition endCondition;
  final int workSec;
  final int restSec;

  /// 시간 모드는 라운드, 횟수 모드는 세트
  final int rounds;
  final int reps;
  final Tempo tempo;

  /// [base]의 id와 이름은 두고 설정만 이 값으로 바꾼 루틴
  Routine applyTo(Routine base) => Routine(
    id: base.id,
    name: base.name,
    endCondition: endCondition,
    prepMs: 10000,
    workMs: workSec * 1000,
    targetReps: reps,
    tempo: tempo,
    restMs: restSec * 1000,
    rounds: rounds,
  );
}

/// 운동 하나: 한국어·영어 이름과 기본 설정.
/// 이름은 운동 중 그 언어의 음성으로 읽히므로 자연스럽게 읽히는 표기를 쓴다.
class Exercise {
  const Exercise(this.ko, this.en, this.defaults);
  final String ko;
  final String en;
  final ExerciseDefaults defaults;

  String nameFor(String languageCode) => languageCode == 'en' ? en : ko;
}

/// 루틴 이름 자동완성에 쓰는 널리 알려진 운동과 기본 설정.
/// 이름은 [RoutineLimits.maxNameLength] 이하여야 한다.
abstract final class ExerciseNames {
  // 시간 모드 묶음
  static const _hold = ExerciseDefaults.time(30, 30, 3);
  static const _cardio = ExerciseDefaults.time(40, 20, 5);

  // 횟수 모드 묶음
  static const _slow = Tempo.slow;
  static const _normal = Tempo.normal;
  static const _lower = ExerciseDefaults.reps(15, _normal, 3, 60);
  static const _lunge = ExerciseDefaults.reps(12, _normal, 3, 60);
  static const _glute = ExerciseDefaults.reps(15, _normal, 3, 30);
  static const _pushup = ExerciseDefaults.reps(12, _normal, 3, 60);
  static const _hardPush = ExerciseDefaults.reps(10, _normal, 3, 60);
  static const _abs = ExerciseDefaults.reps(20, _normal, 3, 45);
  static const _core = ExerciseDefaults.reps(12, _normal, 3, 45);
  static const _compound = ExerciseDefaults.reps(10, _slow, 3, 90);
  static const _isolation = ExerciseDefaults.reps(15, _normal, 3, 60);
  static const _jump = ExerciseDefaults.reps(10, _normal, 3, 60);

  /// 순서가 자동완성 후보 순서다.
  static const list = <Exercise>[
    // 하체
    Exercise('스쿼트', 'Squat', _lower),
    Exercise('점프 스쿼트', 'Jump Squat', _cardio),
    Exercise('와이드 스쿼트', 'Wide Squat', _lower),
    Exercise('스모 스쿼트', 'Sumo Squat', _lower),
    Exercise('불가리안 스플릿 스쿼트', 'Bulgarian Squat', _lunge),
    Exercise('고블릿 스쿼트', 'Goblet Squat', _lower),
    Exercise('월 스쿼트', 'Wall Sit', _hold),
    Exercise('런지', 'Lunge', _lunge),
    Exercise('리버스 런지', 'Reverse Lunge', _lunge),
    Exercise('사이드 런지', 'Side Lunge', _lunge),
    Exercise('워킹 런지', 'Walking Lunge', _lunge),
    Exercise('점프 런지', 'Jump Lunge', _cardio),
    Exercise('커트시 런지', 'Curtsy Lunge', _lunge),
    Exercise('레그 프레스', 'Leg Press', _compound),
    Exercise('레그 익스텐션', 'Leg Extension', _isolation),
    Exercise('레그 컬', 'Leg Curl', _isolation),
    Exercise('카프 레이즈', 'Calf Raise', ExerciseDefaults.reps(20, _normal, 3, 45)),
    Exercise('힙 쓰러스트', 'Hip Thrust', _lower),
    Exercise('글루트 브릿지', 'Glute Bridge', _lower),
    Exercise('동키 킥', 'Donkey Kick', _glute),
    Exercise('파이어 하이드런트', 'Fire Hydrant', _glute),
    Exercise('스텝업', 'Step-up', _lower),
    Exercise('데드리프트', 'Deadlift', _compound),
    Exercise('루마니안 데드리프트', 'Romanian Deadlift', _compound),
    // 가슴·어깨·팔
    Exercise('푸시업', 'Push-up', _pushup),
    Exercise('니 푸시업', 'Knee Push-up', _pushup),
    Exercise('와이드 푸시업', 'Wide Push-up', _pushup),
    Exercise('다이아몬드 푸시업', 'Diamond Push-up', _hardPush),
    Exercise('인클라인 푸시업', 'Incline Push-up', _pushup),
    Exercise('디클라인 푸시업', 'Decline Push-up', _pushup),
    Exercise('파이크 푸시업', 'Pike Push-up', _hardPush),
    Exercise('벤치 프레스', 'Bench Press', _compound),
    Exercise('덤벨 프레스', 'Dumbbell Press', _compound),
    Exercise('체스트 플라이', 'Chest Fly', _isolation),
    Exercise('딥스', 'Dips', _hardPush),
    Exercise('숄더 프레스', 'Shoulder Press', _compound),
    Exercise('사이드 레터럴 레이즈', 'Lateral Raise', _isolation),
    Exercise('프론트 레이즈', 'Front Raise', _isolation),
    Exercise('리어 델트 플라이', 'Rear Delt Fly', _isolation),
    Exercise('바이셉 컬', 'Biceps Curl', _isolation),
    Exercise('해머 컬', 'Hammer Curl', _isolation),
    Exercise('트라이셉스 익스텐션', 'Triceps Extension', _isolation),
    Exercise('킥백', 'Kickback', _isolation),
    // 등
    Exercise('풀업', 'Pull-up', ExerciseDefaults.reps(8, _slow, 3, 120)),
    Exercise('친업', 'Chin-up', ExerciseDefaults.reps(8, _slow, 3, 120)),
    Exercise('랫 풀다운', 'Lat Pulldown', _compound),
    Exercise('바벨 로우', 'Barbell Row', _compound),
    Exercise('덤벨 로우', 'Dumbbell Row', _compound),
    Exercise('시티드 로우', 'Seated Row', _compound),
    Exercise('슈퍼맨', 'Superman', _core),
    Exercise('굿모닝', 'Good Morning', _isolation),
    Exercise('페이스 풀', 'Face Pull', _isolation),
    // 코어·복근
    Exercise('플랭크', 'Plank', _hold),
    Exercise('사이드 플랭크', 'Side Plank', _hold),
    Exercise('리버스 플랭크', 'Reverse Plank', _hold),
    Exercise('플랭크 잭', 'Plank Jack', _cardio),
    Exercise('크런치', 'Crunch', _abs),
    Exercise('바이시클 크런치', 'Bicycle Crunch', _abs),
    Exercise('리버스 크런치', 'Reverse Crunch', _abs),
    Exercise('싯업', 'Sit-up', _abs),
    Exercise('레그 레이즈', 'Leg Raise', _core),
    Exercise('행잉 레그 레이즈', 'Hanging Leg Raise', _core),
    Exercise('러시안 트위스트', 'Russian Twist', _abs),
    Exercise('데드버그', 'Dead Bug', _core),
    Exercise('버드독', 'Bird Dog', _core),
    Exercise('브이업', 'V-up', _core),
    Exercise('할로우 홀드', 'Hollow Hold', _hold),
    Exercise('플러터 킥', 'Flutter Kick', _cardio),
    Exercise('시저 킥', 'Scissor Kick', _cardio),
    Exercise('마운틴 클라이머', 'Mountain Climber', _cardio),
    Exercise('힐 터치', 'Heel Touch', _abs),
    Exercise('토 터치', 'Toe Touch', _abs),
    // 전신·유산소
    Exercise('버피', 'Burpee', _cardio),
    Exercise('점핑잭', 'Jumping Jack', _cardio),
    Exercise('하이니', 'High Knees', _cardio),
    Exercise('버트 킥', 'Butt Kick', _cardio),
    Exercise('스케이터', 'Skater', _cardio),
    Exercise('섀도 복싱', 'Shadow Boxing', _cardio),
    Exercise('줄넘기', 'Jump Rope', ExerciseDefaults.time(60, 30, 5)),
    Exercise('케틀벨 스윙', 'Kettlebell Swing', _cardio),
    Exercise('스러스터', 'Thruster', _compound),
    Exercise('베어 크롤', 'Bear Crawl', _cardio),
    Exercise('인치웜', 'Inchworm', _cardio),
    Exercise('스프린트', 'Sprint', ExerciseDefaults.time(30, 90, 6)),
    Exercise('제자리 달리기', 'Running in Place', _cardio),
    Exercise('박스 점프', 'Box Jump', _jump),
    Exercise('턱 점프', 'Tuck Jump', _cardio),
    Exercise('월 볼', 'Wall Ball', _jump),
    // 스트레칭·기타
    Exercise('스트레칭', 'Stretching', ExerciseDefaults.time(30, 5, 10)),
    Exercise('폼롤러', 'Foam Rolling', ExerciseDefaults.time(45, 15, 6)),
    Exercise('요가', 'Yoga', ExerciseDefaults.time(60, 10, 10)),
    Exercise('필라테스', 'Pilates', ExerciseDefaults.time(45, 15, 8)),
    Exercise(
      '브리딩',
      'Breathing',
      ExerciseDefaults.reps(
        10,
        Tempo(downMs: 4000, holdMs: 2000, upMs: 4000),
        1,
        0,
      ),
    ),
    Exercise('쿨다운', 'Cool-down', ExerciseDefaults.time(300, 0, 1)),
    Exercise('워밍업', 'Warm-up', ExerciseDefaults.time(300, 0, 1)),
    // 인터벌 방식 (타바타·HIIT는 프리셋과 같은 값)
    Exercise('타바타', 'Tabata', ExerciseDefaults.time(20, 10, 8)),
    Exercise('HIIT', 'HIIT', ExerciseDefaults.time(40, 20, 8)),
    Exercise('EMOM', 'EMOM', ExerciseDefaults.time(60, 0, 10)),
    Exercise('AMRAP', 'AMRAP', ExerciseDefaults.time(600, 0, 1)),
    Exercise('서킷 트레이닝', 'Circuit Training', ExerciseDefaults.time(45, 15, 10)),
    Exercise('인터벌 러닝', 'Interval Running', ExerciseDefaults.time(60, 90, 8)),
  ];

  /// 언어별 이름 목록 ([languageCode]가 en이면 영어, 아니면 한국어)
  static List<String> namesFor(String languageCode) => [
    for (final e in list) e.nameFor(languageCode),
  ];

  /// 한국어 이름 목록
  static final all = namesFor('ko');

  /// 한국어나 영어 이름으로 찾은 기본 설정. 대소문자는 무시한다.
  static ExerciseDefaults? defaultsOf(String name) {
    final n = name.trim().toLowerCase();
    for (final e in list) {
      if (e.ko == name.trim() || e.en.toLowerCase() == n) return e.defaults;
    }
    return null;
  }
}
