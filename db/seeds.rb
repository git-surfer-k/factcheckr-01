# frozen_string_literal: true

# 씨드 데이터: 채널 30개, 팩트체크 150개, 주장 ~500개, 뉴스 소스 ~1000개
# 실행: bin/rails db:seed

puts "=== Factis 씨드 데이터 생성 시작 ==="

# ---------- 1. B2C 사용자 5명 ----------
# 각 사용자는 관심 카테고리가 다르며, 해당 카테고리 채널의 팩트체크를 요청한다.
SEED_USERS = [
  { email: "jihye.kim@gmail.com",   name: "김지혜", token: "token-jihye-001",   sub: :b2c_premium, interests: "정치·경제 관심" },
  { email: "minsoo.park@naver.com", name: "박민수", token: "token-minsoo-002",  sub: :b2c_basic,   interests: "사회·교육 관심" },
  { email: "yuna.lee@kakao.com",    name: "이유나", token: "token-yuna-003",    sub: :b2c_premium, interests: "국제·외교 관심" },
  { email: "dongwon.choi@gmail.com",name: "최동원", token: "token-dongwon-004", sub: :b2c_basic,   interests: "경제·투자 관심" },
  { email: "soojin.han@naver.com",  name: "한수진", token: "token-soojin-005",  sub: nil,          interests: "종합 시사 관심 (무료)" },
].freeze

# 사용자별 담당 채널 (인덱스 기반, 겹치지 않게 분배)
# 30개 채널을 5명에게 6개씩 배분
USER_CHANNEL_MAP = {
  0 => [0, 1, 2, 3, 4, 5],          # 김지혜: 정치 채널 6개 (30건)
  1 => [6, 7, 8, 9, 10, 11],        # 박민수: 경제 채널 6개 (30건)
  2 => [12, 13, 14, 15, 16, 17],    # 이유나: 사회 채널 전반 6개 (30건)
  3 => [18, 19, 20, 21, 22, 23],    # 최동원: 국제 채널 6개 (30건)
  4 => [24, 25, 26, 27, 28, 29],    # 한수진: 종합/기타 채널 6개 (30건)
}.freeze

seed_users = SEED_USERS.map.with_index do |u_data, u_idx|
  user = User.find_or_create_by!(email: u_data[:email]) do |u|
    u.name = u_data[:name]
    u.user_type = :b2c
    u.password = "seed_password_not_used"
    u.is_active = true
  end

  # 세션 토큰
  Session.find_or_create_by!(user: user) do |s|
    s.token = u_data[:token]
    s.ip_address = "127.0.0.1"
    s.user_agent = "Seed/1.0"
  end

  # 구독 (5번째 사용자는 무료)
  if u_data[:sub] && !user.subscriptions.active.exists?
    Subscription.create!(
      user: user,
      plan_type: u_data[:sub],
      status: :active,
      started_at: rand(10..60).days.ago,
      expires_at: rand(300..350).days.from_now,
      payment_method: "card"
    )
  end

  puts "  사용자 #{u_idx + 1}: #{user.email} (#{u_data[:name]}) — #{u_data[:interests]}"
  user
end

# 기존 호환용 (태그 생성 등에서 사용)
user = seed_users.first

# ---------- 2. 채널 정의 (30개, 5개 카테고리) ----------
CHANNELS = [
  # 정치 (6개)
  { name: "팩트뉴스TV", category: "정치", trust: 92, subs: 520_000, desc: "정치 뉴스 팩트체크 전문 채널. 주요 정치인 발언과 정책을 객관적 데이터로 검증합니다." },
  { name: "정치비평", category: "정치", trust: 35, subs: 310_000, desc: "정치 시사 비평 채널. 야당 관점에서 정부 정책을 분석합니다." },
  { name: "국회워치", category: "정치", trust: 78, subs: 180_000, desc: "국회 본회의와 상임위를 실시간 중계하고 분석하는 채널입니다." },
  { name: "대한민국정치", category: "정치", trust: 22, subs: 450_000, desc: "정치 뒷이야기와 비화를 전하는 채널. 속보와 단독 보도를 표방합니다." },
  { name: "정책연구소", category: "정치", trust: 88, subs: 95_000, desc: "정책 연구원 출신 전문가들이 운영하는 학술적 정치 분석 채널입니다." },
  { name: "선거전략가", category: "정치", trust: 55, subs: 220_000, desc: "선거 전략과 여론조사를 분석하는 채널. 각종 선거 전망을 다룹니다." },
  # 경제 (6개)
  { name: "경제돋보기", category: "경제", trust: 85, subs: 380_000, desc: "경제 지표와 통계를 기반으로 한국 경제를 분석하는 채널입니다." },
  { name: "부동산의신", category: "경제", trust: 28, subs: 620_000, desc: "부동산 투자 전망과 시세 분석을 다루는 채널. 과감한 전망이 특징입니다." },
  { name: "주식마스터", category: "경제", trust: 52, subs: 440_000, desc: "주식 시장 분석과 종목 추천을 하는 채널. 투자 초보자 대상입니다." },
  { name: "글로벌경제", category: "경제", trust: 82, subs: 210_000, desc: "미국, 중국, 유럽 등 국제 경제 동향을 분석하는 채널입니다." },
  { name: "서민경제TV", category: "경제", trust: 65, subs: 150_000, desc: "물가, 금리, 가계부채 등 서민 생활 경제를 다루는 채널입니다." },
  { name: "코인분석가", category: "경제", trust: 18, subs: 280_000, desc: "비트코인, 이더리움 등 암호화폐 시세 전망과 투자 전략을 다룹니다." },
  # 사회 (6개)
  { name: "사회탐사", category: "사회", trust: 90, subs: 340_000, desc: "사회 이슈를 깊이 파고드는 탐사보도 전문 채널입니다." },
  { name: "교육현장", category: "사회", trust: 80, subs: 120_000, desc: "교육 정책, 입시 제도, 학교 현장을 다루는 교육 전문 채널입니다." },
  { name: "환경지킴이", category: "사회", trust: 62, subs: 95_000, desc: "기후변화, 환경오염, 에너지 전환 등 환경 이슈를 다룹니다." },
  { name: "범죄실록", category: "사회", trust: 40, subs: 580_000, desc: "실제 범죄 사건을 재구성하고 분석하는 채널입니다." },
  { name: "의료진실", category: "사회", trust: 25, subs: 410_000, desc: "건강 정보와 의료 이슈를 다루는 채널. 대체의학도 소개합니다." },
  { name: "복지뉴스", category: "사회", trust: 75, subs: 88_000, desc: "복지 정책, 사회안전망, 취약계층 이슈를 전문으로 다룹니다." },
  # 국제 (6개)
  { name: "세계뉴스24", category: "국제", trust: 87, subs: 290_000, desc: "전 세계 주요 뉴스를 빠르고 정확하게 전달하는 국제 뉴스 채널입니다." },
  { name: "미국통신", category: "국제", trust: 45, subs: 350_000, desc: "미국 정치, 경제, 사회를 다루는 채널. 한미 관계 분석도 합니다." },
  { name: "동아시아포커스", category: "국제", trust: 83, subs: 160_000, desc: "한중일 관계, 북한 이슈, 동아시아 정세를 분석하는 채널입니다." },
  { name: "중동리포트", category: "국제", trust: 58, subs: 75_000, desc: "중동 지역 분쟁, 에너지 정세, 외교 관계를 다루는 채널입니다." },
  { name: "유럽브리핑", category: "국제", trust: 80, subs: 110_000, desc: "EU 정책, 유럽 경제, 사회 이슈를 다루는 유럽 전문 채널입니다." },
  { name: "글로벌위기", category: "국제", trust: 30, subs: 520_000, desc: "국제 분쟁, 경제 위기, 자연재해 등 위기 상황을 다루는 채널입니다." },
  # 종합/기타 (6개)
  { name: "뉴스종합", category: "정치", trust: 86, subs: 430_000, desc: "정치, 경제, 사회, 국제를 아우르는 종합 뉴스 채널입니다." },
  { name: "이슈분석가", category: "사회", trust: 60, subs: 200_000, desc: "주간 핫이슈를 선정하여 다각도로 분석하는 시사 채널입니다." },
  { name: "가짜뉴스헌터", category: "사회", trust: 95, subs: 680_000, desc: "SNS에서 퍼지는 가짜뉴스를 찾아 검증하는 팩트체크 전문 채널입니다." },
  { name: "자유언론", category: "정치", trust: 15, subs: 390_000, desc: "주류 언론이 보도하지 않는 진실을 파헤치겠다는 채널입니다." },
  { name: "과학기술TV", category: "사회", trust: 84, subs: 170_000, desc: "최신 과학 연구, AI, 우주, 에너지 기술을 소개하는 채널입니다." },
  { name: "시민기자단", category: "사회", trust: 50, subs: 130_000, desc: "시민 참여형 뉴스 채널. 현장 제보와 시민 의견을 전달합니다." },
].freeze

# ---------- 3. 시나리오 데이터 ----------
# [제목, 요약, [주장들]]  주장: [텍스트, 설명]
SCENARIOS = {
  "정치" => [
    ["2026년 예산안 분석", "2026년 정부 예산안 639조 원의 주요 배분과 전년 대비 증감을 분석합니다.",
      [["2026년 정부 예산안 총액은 639조 원이다", "기획재정부 발표 자료와 일치합니다."],
       ["국방 예산이 전년 대비 5.2% 증가했다", "국방부 예산안 기준으로 정확한 수치입니다."],
       ["복지 예산은 역대 최대 규모이다", "총액은 최대이나 GDP 대비 비율은 감소하여 맥락이 부족합니다."]]],
    ["지방선거 여론조사 해석", "최신 여론조사 결과를 분석하고 후보 지지율 변화 추이를 살펴봅니다.",
      [["A후보 지지율이 45.2%로 1위다", "해당 여론조사 기관의 발표 수치와 일치합니다."],
       ["오차범위 내 역전이 가능하다", "통계적으로 정확한 해석입니다."],
       ["투표율이 60%를 넘으면 야당에 유리하다", "과거 선거 데이터를 일부 왜곡하여 해석한 주장입니다."]]],
    ["국회 법안 처리 현황", "21대 국회의 법안 처리율과 주요 쟁점 법안 진행 상황을 정리합니다.",
      [["21대 국회 법안 처리율은 42%이다", "국회 의안정보시스템 기준 정확한 수치입니다."],
       ["민생 법안 85건이 계류 중이다", "계류 법안 수는 기준에 따라 다를 수 있으나 대체로 정확합니다."],
       ["법안 자동 폐기 제도를 개선해야 한다", "이것은 주장이지 사실 검증 대상이 아닙니다."]]],
    ["대통령 지지율 분석", "최근 3개월간 대통령 지지율 추이와 주요 변동 요인을 분석합니다.",
      [["대통령 지지율이 3주 연속 하락했다", "주요 여론조사 기관 3곳의 데이터와 일치합니다."],
       ["경제 불만이 지지율 하락의 주요 원인이다", "교차분석 결과 경제 불만족 그룹에서 이탈이 두드러집니다."],
       ["지지율 40% 이하로 떨어지면 레임덕이다", "역대 사례에서 항상 그런 것은 아니므로 과장된 주장입니다."]]],
    ["개각 인사 평가", "최근 내각 개편의 인선 배경과 각 부처 장관 후보자 이력을 분석합니다.",
      [["신임 경제부총리는 전 한국은행 부총재 출신이다", "공개된 이력과 일치하는 사실입니다."],
       ["이번 개각에서 여성 장관 비율이 30%이다", "실제 비율은 25%로 다소 과장되었습니다."],
       ["국방장관 후보자의 병역 의혹이 있다", "관련 보도가 있으나 사실 확인이 필요한 단계입니다."]]],
  ],
  "경제" => [
    ["GDP 성장률 전망", "2026년 한국 GDP 성장률 전망치를 주요 기관별로 비교 분석합니다.",
      [["한국은행이 올해 성장률을 2.1%로 전망했다", "한국은행 경제전망보고서의 공식 수치입니다."],
       ["IMF 전망치는 한국은행보다 0.3%p 낮다", "IMF WEO 보고서 기준으로 정확합니다."],
       ["수출이 성장률의 핵심 변수이다", "경제학적으로 타당한 분석입니다."]]],
    ["금리 인하 영향 분석", "기준금리 인하 결정의 배경과 부동산·주식·환율에 미치는 영향을 분석합니다.",
      [["기준금리가 3.0%에서 2.75%로 인하되었다", "한국은행 금통위 결정 사항과 일치합니다."],
       ["금리 인하 시 주택 가격이 반드시 상승한다", "과거 사례에서 항상 그런 것은 아니므로 과장입니다."],
       ["가계부채가 1,900조 원을 넘었다", "한국은행 통계와 일치하는 정확한 수치입니다."]]],
    ["물가 상승률 진단", "최근 소비자물가 상승률 추이와 품목별 가격 변동을 분석합니다.",
      [["3월 소비자물가 상승률은 2.8%이다", "통계청 발표 수치와 일치합니다."],
       ["농산물 가격이 전년 대비 15% 올랐다", "일부 품목만 해당하며 전체 평균은 8.3%입니다."],
       ["체감물가가 공식 물가보다 높다", "생활물가지수와 소비자물가지수 차이에 대한 정확한 설명입니다."]]],
    ["반도체 수출 동향", "한국 반도체 수출 실적과 글로벌 시장 점유율 변화를 분석합니다.",
      [["반도체 수출이 전년 대비 32% 증가했다", "관세청 수출 통계와 일치하는 수치입니다."],
       ["삼성전자 HBM 점유율이 40%이다", "실제 점유율은 약 25%로 과장된 수치입니다."],
       ["AI 칩 수요가 메모리 가격 상승을 이끌고 있다", "업계 분석과 일치하는 정확한 분석입니다."]]],
    ["청년 실업률 분석", "청년층 고용 지표를 분석하고 체감 고용률과의 괴리를 설명합니다.",
      [["청년 실업률이 7.2%이다", "통계청 고용동향조사 기준 정확한 수치입니다."],
       ["체감 실업률은 공식 수치의 2배이다", "확장실업률 기준으로 대체로 맞는 설명입니다."],
       ["공공 일자리가 청년 고용의 절반이다", "실제로는 약 18%로 크게 과장된 주장입니다."]]],
  ],
  "사회" => [
    ["저출생 대책 분석", "정부의 저출생 대응 정책 효과와 OECD 비교를 통해 현황을 진단합니다.",
      [["합계출산율이 0.72로 역대 최저이다", "통계청 발표 수치와 일치합니다."],
       ["육아휴직 급여가 월 150만 원으로 인상되었다", "고용노동부 발표와 일치하는 사실입니다."],
       ["프랑스의 출산율 반등은 보육 정책 덕분이다", "여러 요인이 복합적이나 핵심인 것은 맞습니다."]]],
    ["의대 정원 확대 논란", "의대 정원 확대 정책의 배경과 의료계 반발, 지역 의료 격차를 분석합니다.",
      [["의대 정원을 2,000명 증원하기로 했다", "정부 발표 내용과 일치합니다."],
       ["한국의 인구 대비 의사 수는 OECD 최하위이다", "OECD 통계 기준으로 정확한 사실입니다."],
       ["의사 수 증가가 의료비 상승을 초래한다", "일부 연구에서 지적되나 보편적으로 입증된 것은 아닙니다."]]],
    ["AI 일자리 영향", "생성형 AI의 확산이 한국 노동시장에 미치는 영향을 분석합니다.",
      [["AI로 인해 5년 내 300만 개 일자리가 사라진다", "특정 연구의 수치를 인용했으나 불확실성이 큽니다."],
       ["AI 관련 신규 일자리가 연 5만 개 생긴다", "고용노동부 추정치와 대체로 일치합니다."],
       ["번역, 고객상담 직군이 가장 큰 영향을 받는다", "여러 연구에서 일관되게 지적하는 사실입니다."]]],
    ["학교 폭력 실태", "최근 학교폭력 실태조사 결과와 대응 정책의 효과를 분석합니다.",
      [["학교폭력 피해 응답률이 1.9%이다", "교육부 실태조사 공식 수치입니다."],
       ["사이버 폭력이 전체의 35%를 차지한다", "실제 비율은 약 20%로 과장되었습니다."],
       ["학폭 전담 경찰관이 전국에 500명이다", "경찰청 자료와 일치하는 수치입니다."]]],
    ["기후변화와 폭우", "집중호우와 기후변화의 관계, 도시 방재 인프라 현황을 분석합니다.",
      [["올해 여름 강수량이 평년 대비 140%이다", "기상청 관측 데이터와 일치합니다."],
       ["서울 하수관거 노후화율이 40%이다", "서울시 통계와 일치하는 정확한 수치입니다."],
       ["100년 빈도 폭우가 10년마다 온다", "기후과학 연구 결과와 대체로 일치하는 분석입니다."]]],
  ],
  "국제" => [
    ["미중 무역 갈등 분석", "미중 무역 분쟁의 현황과 한국 경제에 미치는 영향을 분석합니다.",
      [["미국이 중국산 제품에 25% 관세를 부과했다", "미국 무역대표부(USTR) 발표와 일치합니다."],
       ["한국 수출의 25%가 중국으로 향한다", "관세청 통계 기준으로 정확한 비율입니다."],
       ["반도체 수출 규제가 한국 기업에 직접 영향을 준다", "업계 분석과 일치하는 정확한 판단입니다."]]],
    ["우크라이나 전쟁 현황", "우크라이나-러시아 전쟁의 최신 전황과 평화 협상 가능성을 분석합니다.",
      [["전쟁이 시작된 지 4년이 넘었다", "2022년 2월 개전 기준으로 정확합니다."],
       ["우크라이나 사망자가 50만 명에 달한다", "공식 확인된 수치가 아니며 추정치 간 차이가 큽니다."],
       ["NATO 군사 지원 총액이 2,000억 달러이다", "Kiel Institute 추적 데이터와 대체로 일치합니다."]]],
    ["일본 경제 회복", "일본의 디플레이션 탈출과 엔저 현상이 한국에 미치는 영향을 분석합니다.",
      [["일본 GDP가 세계 4위로 떨어졌다", "IMF 통계 기준으로 정확한 사실입니다."],
       ["엔화가 달러 대비 155엔까지 하락했다", "외환시장 환율 기준 정확합니다."],
       ["엔저로 한국 관광 수입이 20% 감소했다", "한국관광공사 통계와 비교하면 과장된 수치입니다."]]],
    ["중동 정세 변화", "이스라엘-팔레스타인 갈등과 에너지 시장에 미치는 영향을 분석합니다.",
      [["국제 유가가 배럴당 90달러를 돌파했다", "WTI 기준 특정 시점에서 정확했습니다."],
       ["한국의 중동 원유 의존도가 70%이다", "에너지경제연구원 통계와 일치합니다."],
       ["호르무즈 해협 봉쇄 시 한국 경제가 마비된다", "극단적 시나리오이며 실현 가능성은 낮습니다."]]],
    ["글로벌 AI 규제 동향", "EU AI법, 미국 행정명령 등 글로벌 AI 규제 동향과 한국의 대응을 분석합니다.",
      [["EU AI법이 2024년부터 시행되었다", "EU AI Act의 단계적 시행 일정과 일치합니다."],
       ["미국은 AI 규제보다 혁신을 우선시한다", "미국 정부의 공식 입장과 대체로 일치합니다."],
       ["한국 AI 기본법이 아직 통과되지 않았다", "국회 법안 진행 상황을 정확히 반영합니다."]]],
  ],
}.freeze

# 채널별 신뢰도 추이 시나리오 (12개월)
CHANNEL_TRENDS = {
  # 정치
  "팩트뉴스TV"   => :stable,        # 꾸준히 높은 신뢰도 유지
  "정치비평"     => :falling,       # 점점 더 편향되어 하락
  "국회워치"     => :rising,        # 꾸준히 개선 중
  "대한민국정치"  => :sudden_drop,   # 음모론 논란으로 최근 급락
  "정책연구소"   => :stable,        # 학술적 분석으로 안정
  "선거전략가"   => :volatile,      # 선거 시즌마다 등락
  "뉴스종합"     => :stable,        # 안정적 종합 뉴스
  "자유언론"     => :falling,       # 점점 더 자극적으로 하락
  # 경제
  "경제돋보기"   => :rising,        # 데이터 기반 분석 강화로 상승
  "부동산의신"   => :peak_fall,     # 부동산 호황 시 정점 후 하락
  "주식마스터"   => :volatile,      # 시장 상황에 따라 등락
  "글로벌경제"   => :stable,        # 국제 경제 분석 꾸준
  "서민경제TV"   => :rising,        # 생활 밀착형 보도로 상승
  "코인분석가"   => :sudden_drop,   # 코인 폭락 후 신뢰도 급락
  # 사회
  "사회탐사"     => :stable,        # 탐사보도 전문 안정
  "교육현장"     => :rising,        # 교육 이슈 전문성 강화
  "환경지킴이"   => :v_recovery,    # 과장 보도 논란 후 회복
  "범죄실록"     => :falling,       # 선정적 보도 증가로 하락
  "의료진실"     => :sudden_drop,   # 의료 오보 사건으로 급락
  "복지뉴스"     => :rising,        # 복지 정책 정확도 향상
  "이슈분석가"   => :volatile,      # 이슈에 따라 등락
  "가짜뉴스헌터" => :stable,        # 팩트체크 전문 안정
  "과학기술TV"   => :sudden_rise,   # AI 시대 주목받으며 급등
  "시민기자단"   => :v_recovery,    # 초기 혼란 후 안정화
  # 국제
  "세계뉴스24"   => :stable,        # 글로벌 뉴스 안정
  "미국통신"     => :peak_fall,     # 선거 시즌 정점 후 편향 심화
  "동아시아포커스" => :rising,       # 동아시아 전문성 강화
  "중동리포트"   => :volatile,      # 분쟁 상황에 따라 등락
  "유럽브리핑"   => :stable,        # EU 뉴스 안정적
  "글로벌위기"   => :falling,       # 과장 보도 증가로 하락
}.freeze

PUBLISHERS = %w[한겨레 조선일보 중앙일보 경향신문 동아일보 한국경제 매일경제 연합뉴스 KBS MBC SBS JTBC YTN].freeze
REPORTERS = %w[김서연 이준호 박지민 최영수 정하늘 강민서 윤도현 한소희 오세진 임채원].freeze

# ---------- 4. 데이터 생성 ----------
CHANNELS.each_with_index do |ch, idx|
  # 채널 생성
  channel = Channel.find_or_create_by!(youtube_channel_id: "UC_factis_seed_#{idx + 1}") do |c|
    c.name = ch[:name]
    c.description = ch[:desc]
    c.subscriber_count = ch[:subs]
    c.category = ch[:category]
    c.trust_score = ch[:trust]
    c.total_checks = 5
    c.thumbnail_url = ""
  end

  # 채널 점수 이력 (12개월치, 채널별 추세 시나리오)
  trend = CHANNEL_TRENDS[ch[:name]] || :stable
  base = ch[:trust].to_f
  12.times do |m|
    recorded = (12 - m).months.ago.beginning_of_month
    progress = m / 11.0  # 0.0(12개월전) → 1.0(현재)
    offset = case trend
             when :rising      then -15 + (15 * progress)                          # 꾸준히 상승
             when :falling     then 10 - (15 * progress)                           # 꾸준히 하락
             when :v_recovery  then (progress < 0.5 ? -20 * (1 - 2*progress) : -20 + 25 * (2*progress - 1))  # V자 반등
             when :peak_fall   then (progress < 0.6 ? 10 * progress/0.6 : 10 - 18 * (progress - 0.6)/0.4)    # 정점 후 하락
             when :volatile    then Math.sin(progress * 4 * Math::PI) * 12         # 등락 반복
             when :sudden_rise then (progress < 0.7 ? rand(-3.0..3.0) : (progress - 0.7) / 0.3 * 20)         # 최근 급등
             when :sudden_drop then (progress < 0.7 ? rand(-2.0..2.0) : -(progress - 0.7) / 0.3 * 25)        # 최근 급락
             else rand(-4.0..4.0)                                                  # 안정
             end
    score = [[base + offset + rand(-2.0..2.0), 5].max, 98].min.round(2)
    ChannelScore.find_or_create_by!(channel: channel, recorded_at: recorded) do |cs|
      cs.score = score
      cs.accuracy_rate = [[score + rand(-5.0..5.0), 5].max, 98].min.round(2)
      cs.source_citation_rate = [[score + rand(-8.0..8.0), 5].max, 98].min.round(2)
      cs.consistency_score = [[score + rand(-4.0..4.0), 5].max, 98].min.round(2)
    end
  end

  # 채널 태그
  category_tags = { "정치" => %w[정치 시사], "경제" => %w[경제 금융], "사회" => %w[사회 생활], "국제" => %w[국제 외교] }
  (category_tags[ch[:category]] || %w[종합]).each do |tag|
    ChannelTag.find_or_create_by!(channel: channel, tag_name: tag) do |ct|
      ct.created_by = user.id
    end
  end

  # 신뢰도에 따른 verdict 분포
  verdict_pool = if ch[:trust] >= 80
    %i[true_claim true_claim mostly_true true_claim mostly_true]
  elsif ch[:trust] >= 60
    %i[true_claim mostly_true half_true mostly_true true_claim]
  elsif ch[:trust] >= 40
    %i[half_true mostly_false mostly_true half_true false_claim]
  else
    %i[false_claim mostly_false false_claim half_true mostly_false]
  end

  # 팩트체크 5개 생성 — 채널별로 담당 사용자 배정
  owner = seed_users[USER_CHANNEL_MAP.find { |_, channels| channels.include?(idx) }&.first || 0]
  scenarios = SCENARIOS[ch[:category]] || SCENARIOS["정치"]
  scenarios.each_with_index do |scenario, s_idx|
    title_suffix, summary, claims_data = scenario
    video_id = "seed_v#{idx + 1}_#{s_idx + 1}"
    created = (5 - s_idx).weeks.ago + rand(0..6).days

    fc = FactCheck.find_or_create_by!(youtube_video_id: video_id) do |f|
      f.user = owner
      f.channel = channel
      f.youtube_url = "https://www.youtube.com/watch?v=#{video_id}"
      f.video_title = "#{ch[:name]} — #{title_suffix}"
      f.video_thumbnail = ""  # 동적 썸네일 사용 (/thumbnails/:id)
      f.summary = summary
      f.overall_score = [[ch[:trust] + rand(-8.0..8.0), 0].max, 100].min.round(2)
      f.status = :completed
      f.completed_at = created + 90.seconds
      f.created_at = created
      f.updated_at = created + 90.seconds
    end

    # 주장 + 뉴스소스 생성
    claims_data.each_with_index do |cd, c_idx|
      claim_text, explanation = cd
      v = verdict_pool[c_idx % verdict_pool.size]
      conf_ranges = { true_claim: 85..98, mostly_true: 70..89, half_true: 45..69, mostly_false: 20..44, false_claim: 5..25, unverified: 30..50 }
      confidence = (rand(conf_ranges[v]) / 100.0).round(2)

      claim = Claim.find_or_create_by!(fact_check: fc, claim_text: claim_text) do |c|
        c.verdict = v
        c.confidence = confidence
        c.explanation = explanation
        c.timestamp_start = c_idx * 45 + rand(0..10)
        c.timestamp_end = c.timestamp_start + 30 + rand(0..15)
      end

      # 각 주장당 뉴스소스 2개
      2.times do |n_idx|
        pub = PUBLISHERS.sample
        NewsSource.find_or_create_by!(claim: claim, title: "#{claim_text[0..25]}... 관련 보도 (#{pub})") do |ns|
          ns.url = "https://news.example.com/article/#{fc.id}_#{claim.id}_#{n_idx}"
          ns.publisher = pub
          ns.author = REPORTERS.sample
          ns.published_at = created - rand(1..30).days
          ns.relevance_score = (rand(60..98) / 100.0).round(2)
          ns.bigkinds_doc_id = "BK#{rand(10_000_000..99_999_999)}"
        end
      end
    end
  end

  puts "  [#{idx + 1}/30] #{ch[:name]} (#{ch[:category]}, 신뢰도 #{ch[:trust]}점)"
end

# ---------- 5. B2B 테스트 데이터 ----------
b2b_user = User.find_or_create_by!(email: "biz@factis.com") do |u|
  u.name = "Factis 기업고객"
  u.user_type = :b2b
  u.password = "seed_password_not_used"
  u.is_active = true
end

Session.find_or_create_by!(user: b2b_user) do |s|
  s.token = "test-b2b-session-token-456"
  s.ip_address = "127.0.0.1"
  s.user_agent = "Seed/1.0"
end

unless b2b_user.subscriptions.active.exists?
  Subscription.create!(
    user: b2b_user,
    plan_type: :b2b_standard,
    status: :active,
    started_at: 15.days.ago,
    expires_at: 350.days.from_now,
    payment_method: "invoice"
  )
end

B2bReport.find_or_create_by!(user: b2b_user, company_name: "테크스타트업") do |r|
  r.industry = "IT/소프트웨어"
  r.product_info = "클라우드 기반 SaaS 프로젝트 관리 도구"
  r.target_categories = ["경제", "사회"]
  r.recommended_channels = { channels: [{ name: "경제돋보기", score: 85 }, { name: "과학기술TV", score: 84 }] }
  r.report_data = { summary: "IT/소프트웨어 업종 광고에 적합한 채널 2개를 추천합니다." }
  r.status = :completed
  r.completed_at = 3.days.ago
end

B2bReport.find_or_create_by!(user: b2b_user, company_name: "그린에너지") do |r|
  r.industry = "에너지/환경"
  r.product_info = "태양광 패널 및 ESS 시스템"
  r.target_categories = ["사회", "국제"]
  r.recommended_channels = {}
  r.report_data = {}
  r.status = :analyzing
end

puts "  B2B: biz@factis.com + 리포트 2개"

# ---------- 결과 출력 ----------
puts ""
puts "=== 씨드 데이터 생성 완료 ==="
puts "  채널: #{Channel.count}개"
puts "  팩트체크: #{FactCheck.count}개"
puts "  주장: #{Claim.count}개"
puts "  뉴스소스: #{NewsSource.count}개"
puts "  채널점수: #{ChannelScore.count}개"
puts "  사용자: #{User.count}명"
puts ""
puts "  [사용자별 팩트체크 수]"
seed_users.each do |u|
  s = Session.find_by(user: u)
  puts "    #{u.name} (#{u.email}) — #{u.fact_checks.count}건 | 토큰: #{s&.token}"
end
puts ""
puts "  [로그인 방법] 브라우저 콘솔에서 실행:"
puts "    document.cookie = 'session_token=토큰값; path=/'"
puts "    location.reload()"
