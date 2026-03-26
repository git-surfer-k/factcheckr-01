# frozen_string_literal: true

# 팩트체크 대상 영상의 유튜브 썸네일을 시뮬레이션하는 컨트롤러
# 각 채널의 고유한 디자인 아이덴티티를 반영하여 실제 유튜브 썸네일처럼 보이도록 한다.
class ThumbnailsController < ActionController::Base
  # 채널별 고유 스타일 — 실제 유튜브 채널처럼 각자 다른 디자인
  CHANNEL_STYLES = {
    # 정치 채널
    "팩트뉴스TV" =>    { bg: "#0f172a", accent: "#3b82f6", text_color: "#ffffff", badge: "FACT", badge_bg: "#2563eb", style: :news },
    "정치비평" =>      { bg: "#1a0000", accent: "#ef4444", text_color: "#ffffff", badge: "단독", badge_bg: "#dc2626", style: :dramatic },
    "국회워치" =>      { bg: "#0c0c2e", accent: "#6366f1", text_color: "#e2e8f0", badge: "LIVE", badge_bg: "#4f46e5", style: :news },
    "대한민국정치" =>   { bg: "#000000", accent: "#f59e0b", text_color: "#fbbf24", badge: "긴급", badge_bg: "#b91c1c", style: :clickbait },
    "정책연구소" =>    { bg: "#1e293b", accent: "#94a3b8", text_color: "#f1f5f9", badge: "분석", badge_bg: "#475569", style: :academic },
    "선거전략가" =>    { bg: "#172554", accent: "#60a5fa", text_color: "#dbeafe", badge: "전략", badge_bg: "#1d4ed8", style: :chart },
    "뉴스종합" =>      { bg: "#111827", accent: "#f43f5e", text_color: "#ffffff", badge: "속보", badge_bg: "#e11d48", style: :news },
    "자유언론" =>      { bg: "#000000", accent: "#ef4444", text_color: "#fca5a5", badge: "충격", badge_bg: "#991b1b", style: :clickbait },
    # 경제 채널
    "경제돋보기" =>    { bg: "#022c22", accent: "#10b981", text_color: "#d1fae5", badge: "지표", badge_bg: "#047857", style: :chart },
    "부동산의신" =>    { bg: "#1c1917", accent: "#f59e0b", text_color: "#fef3c7", badge: "폭등?!", badge_bg: "#d97706", style: :clickbait },
    "주식마스터" =>    { bg: "#0c0a09", accent: "#22c55e", text_color: "#bbf7d0", badge: "종목", badge_bg: "#15803d", style: :chart },
    "글로벌경제" =>    { bg: "#0f172a", accent: "#0ea5e9", text_color: "#e0f2fe", badge: "글로벌", badge_bg: "#0369a1", style: :news },
    "서민경제TV" =>    { bg: "#1c1917", accent: "#fb923c", text_color: "#fff7ed", badge: "생활", badge_bg: "#c2410c", style: :friendly },
    "코인분석가" =>    { bg: "#000000", accent: "#a855f7", text_color: "#e9d5ff", badge: "급등", badge_bg: "#7c3aed", style: :clickbait },
    # 사회 채널
    "사회탐사" =>      { bg: "#1e1b4b", accent: "#818cf8", text_color: "#e0e7ff", badge: "탐사", badge_bg: "#4338ca", style: :documentary },
    "교육현장" =>      { bg: "#1e3a5f", accent: "#38bdf8", text_color: "#e0f2fe", badge: "교육", badge_bg: "#0284c7", style: :friendly },
    "환경지킴이" =>    { bg: "#052e16", accent: "#4ade80", text_color: "#dcfce7", badge: "환경", badge_bg: "#15803d", style: :documentary },
    "범죄실록" =>      { bg: "#0a0a0a", accent: "#f87171", text_color: "#fecaca", badge: "실화", badge_bg: "#991b1b", style: :dramatic },
    "의료진실" =>      { bg: "#1a0a2e", accent: "#c084fc", text_color: "#f3e8ff", badge: "건강", badge_bg: "#7e22ce", style: :clickbait },
    "복지뉴스" =>      { bg: "#1e3a5f", accent: "#67e8f9", text_color: "#cffafe", badge: "복지", badge_bg: "#0e7490", style: :friendly },
    "이슈분석가" =>    { bg: "#18181b", accent: "#fbbf24", text_color: "#fef9c3", badge: "이슈", badge_bg: "#a16207", style: :chart },
    "가짜뉴스헌터" =>  { bg: "#14532d", accent: "#22c55e", text_color: "#ffffff", badge: "검증", badge_bg: "#16a34a", style: :news },
    "과학기술TV" =>    { bg: "#0c0a09", accent: "#06b6d4", text_color: "#cffafe", badge: "TECH", badge_bg: "#0891b2", style: :academic },
    "시민기자단" =>    { bg: "#292524", accent: "#f97316", text_color: "#fff7ed", badge: "제보", badge_bg: "#c2410c", style: :friendly },
    # 국제 채널
    "세계뉴스24" =>    { bg: "#0c0f33", accent: "#f43f5e", text_color: "#ffffff", badge: "WORLD", badge_bg: "#be123c", style: :news },
    "미국통신" =>      { bg: "#1e293b", accent: "#3b82f6", text_color: "#dbeafe", badge: "US", badge_bg: "#1d4ed8", style: :news },
    "동아시아포커스" => { bg: "#0f172a", accent: "#f59e0b", text_color: "#fef3c7", badge: "동아시아", badge_bg: "#b45309", style: :documentary },
    "중동리포트" =>    { bg: "#1c1917", accent: "#ef4444", text_color: "#fee2e2", badge: "중동", badge_bg: "#b91c1c", style: :dramatic },
    "유럽브리핑" =>    { bg: "#0f172a", accent: "#6366f1", text_color: "#e0e7ff", badge: "EU", badge_bg: "#4338ca", style: :news },
    "글로벌위기" =>    { bg: "#000000", accent: "#ef4444", text_color: "#fca5a5", badge: "위기", badge_bg: "#7f1d1d", style: :clickbait },
  }.freeze

  def show
    fact_check = FactCheck.includes(:channel).find_by(id: params[:id])
    return head(:not_found) unless fact_check

    channel = fact_check.channel
    channel_name = channel&.name || "알 수 없음"
    style = CHANNEL_STYLES[channel_name] || { bg: "#1e293b", accent: "#64748b", text_color: "#f1f5f9", badge: "뉴스", badge_bg: "#475569", style: :news }

    title = fact_check.video_title || "팩트체크"
    # "채널명 — 주제" 형식에서 주제만 추출
    topic = title.include?("—") ? title.split("—", 2).last.strip : title

    # 주제를 유튜브 썸네일 스타일의 짧은 문구로 변환
    headline = build_headline(topic, style[:style])

    svg = send(:"render_#{style[:style]}", style, channel_name, headline, topic)

    response.headers["Cache-Control"] = "public, max-age=86400"
    render inline: svg, content_type: "image/svg+xml"
  end

  private

  # 스타일별 헤드라인 생성 — 채널 성격에 맞는 제목 표현
  def build_headline(topic, style_type)
    case style_type
    when :clickbait
      # 자극적 — 느낌표, 물음표, 강조
      "#{topic}..#{['충격', '논란', '실화?!', '결국..'].sample}"
    when :dramatic
      # 긴장감 — 따옴표, 말줄임
      "\"#{topic}\" 의 진실"
    when :academic
      # 학술적 — 콜론, 분석
      "#{topic}: 심층분석"
    when :chart
      # 데이터 — 숫자 강조
      "#{topic} 완전정리"
    when :documentary
      # 다큐 — 르포 느낌
      "[르포] #{topic}"
    when :friendly
      # 친근 — 쉬운 말
      "#{topic}, 알기 쉽게!"
    else
      topic
    end
  end

  # --- 뉴스 스타일: 깔끔한 뉴스 채널 느낌 ---
  def render_news(s, ch, headline, _topic)
    lines = split_headline(headline, 10)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <!-- 하단 악센트 바 -->
        <rect y="320" width="640" height="40" fill="#{s[:accent]}"/>
        <!-- 상단 얇은 라인 -->
        <rect width="640" height="4" fill="#{s[:accent]}"/>
        <!-- 배경 패턴: 도트 그리드 -->
        #{dot_grid(s[:accent], 0.06)}
        <!-- 채널명 좌상단 -->
        <rect x="20" y="20" width="#{ch.length * 16 + 24}" height="32" rx="4" fill="#{s[:accent]}"/>
        <text x="32" y="42" fill="white" font-family="sans-serif" font-size="15" font-weight="800">#{esc(ch)}</text>
        <!-- 배지 -->
        <rect x="#{640 - 20 - s[:badge].length * 14 - 16}" y="20" width="#{s[:badge].length * 14 + 16}" height="28" rx="4" fill="#{s[:badge_bg]}"/>
        <text x="#{640 - 20 - s[:badge].length * 7}" y="40" text-anchor="middle" fill="white" font-family="sans-serif" font-size="13" font-weight="700">#{esc(s[:badge])}</text>
        <!-- 메인 헤드라인 (중앙) -->
        <text x="320" y="#{lines.size == 1 ? 195 : 170}" text-anchor="middle" fill="#{s[:text_color]}" font-family="sans-serif" font-size="42" font-weight="900" letter-spacing="-1">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"320\" y=\"225\" text-anchor=\"middle\" fill=\"#{s[:text_color]}\" font-family=\"sans-serif\" font-size=\"42\" font-weight=\"900\" letter-spacing=\"-1\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 바 텍스트 -->
        <text x="320" y="347" text-anchor="middle" fill="white" font-family="sans-serif" font-size="14" font-weight="600">#{esc(ch)} | BREAKING NEWS</text>
      </svg>
    SVG
  end

  # --- 자극적 스타일: 빨간 화살표, 느낌표, 클릭베이트 ---
  def render_clickbait(s, ch, headline, _topic)
    lines = split_headline(headline, 9)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <!-- 대각선 줄무늬 배경 -->
        <defs><pattern id="stripes" patternUnits="userSpaceOnUse" width="20" height="20" patternTransform="rotate(45)">
          <line x1="0" y1="0" x2="0" y2="20" stroke="#{s[:accent]}" stroke-width="2" opacity="0.08"/>
        </pattern></defs>
        <rect width="640" height="360" fill="url(#stripes)"/>
        <!-- 큰 느낌표/물음표 배경 장식 -->
        <text x="500" y="300" fill="#{s[:accent]}" opacity="0.1" font-family="sans-serif" font-size="280" font-weight="900">?!</text>
        <!-- 빨간 배지 (좌상단) -->
        <rect x="16" y="16" width="#{s[:badge].length * 18 + 20}" height="36" rx="4" fill="#{s[:badge_bg]}"/>
        <text x="26" y="41" fill="white" font-family="sans-serif" font-size="18" font-weight="900">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 (크고 굵게, 노란색/빨간색 강조) -->
        <text x="30" y="#{lines.size == 1 ? 210 : 180}" fill="#{s[:text_color]}" font-family="sans-serif" font-size="48" font-weight="900" letter-spacing="-1">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"30\" y=\"240\" fill=\"#{s[:accent]}\" font-family=\"sans-serif\" font-size=\"48\" font-weight=\"900\" letter-spacing=\"-1\">#{esc(lines[1])}</text>" : ""}
        <!-- 채널명 (우하단) -->
        <rect x="#{640 - ch.length * 14 - 32}" y="310" width="#{ch.length * 14 + 20}" height="30" rx="15" fill="#{s[:accent]}" opacity="0.8"/>
        <text x="#{640 - ch.length * 7 - 22}" y="331" text-anchor="middle" fill="white" font-family="sans-serif" font-size="13" font-weight="700">#{esc(ch)}</text>
      </svg>
    SVG
  end

  # --- 극적 스타일: 어두운 배경, 따옴표, 긴장감 ---
  def render_dramatic(s, ch, headline, _topic)
    lines = split_headline(headline, 11)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <defs>
          <radialGradient id="spot" cx="50%" cy="40%"><stop offset="0%" stop-color="#{s[:accent]}" stop-opacity="0.15"/><stop offset="100%" stop-color="#{s[:bg]}" stop-opacity="1"/></radialGradient>
        </defs>
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <rect width="640" height="360" fill="url(#spot)"/>
        <!-- 큰 따옴표 장식 -->
        <text x="40" y="120" fill="#{s[:accent]}" opacity="0.2" font-family="serif" font-size="160" font-weight="900">"</text>
        <!-- 배지 -->
        <rect x="20" y="20" width="#{s[:badge].length * 16 + 20}" height="30" rx="3" fill="#{s[:badge_bg]}"/>
        <text x="30" y="41" fill="white" font-family="sans-serif" font-size="14" font-weight="800">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 -->
        <text x="50" y="#{lines.size == 1 ? 210 : 185}" fill="#{s[:text_color]}" font-family="sans-serif" font-size="38" font-weight="800">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"50\" y=\"235\" fill=\"#{s[:text_color]}\" font-family=\"sans-serif\" font-size=\"38\" font-weight=\"800\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 구분선 + 채널명 -->
        <line x1="50" y1="290" x2="200" y2="290" stroke="#{s[:accent]}" stroke-width="3"/>
        <text x="50" y="320" fill="#{s[:accent]}" font-family="sans-serif" font-size="16" font-weight="700">#{esc(ch)}</text>
      </svg>
    SVG
  end

  # --- 학술 스타일: 깔끔, 데이터 중심 ---
  def render_academic(s, ch, headline, _topic)
    lines = split_headline(headline, 12)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <!-- 좌측 세로 악센트 바 -->
        <rect x="0" width="6" height="360" fill="#{s[:accent]}"/>
        <!-- 격자 배경 -->
        #{grid_lines(s[:accent], 0.05)}
        <!-- 채널명 상단 -->
        <text x="30" y="50" fill="#{s[:accent]}" font-family="sans-serif" font-size="14" font-weight="600" letter-spacing="2">#{esc(ch.upcase)}</text>
        <!-- 구분선 -->
        <line x1="30" y1="65" x2="200" y2="65" stroke="#{s[:accent]}" stroke-width="1" opacity="0.4"/>
        <!-- 배지 -->
        <rect x="30" y="80" width="#{s[:badge].length * 12 + 16}" height="24" rx="3" fill="#{s[:badge_bg]}" opacity="0.8"/>
        <text x="38" y="97" fill="white" font-family="sans-serif" font-size="12" font-weight="600">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 -->
        <text x="30" y="#{lines.size == 1 ? 220 : 195}" fill="#{s[:text_color]}" font-family="sans-serif" font-size="36" font-weight="700" letter-spacing="-0.5">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"30\" y=\"240\" fill=\"#{s[:text_color]}\" font-family=\"sans-serif\" font-size=\"36\" font-weight=\"700\" letter-spacing=\"-0.5\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 -->
        <line x1="30" y1="310" x2="610" y2="310" stroke="#{s[:accent]}" stroke-width="1" opacity="0.2"/>
        <text x="30" y="340" fill="#{s[:accent]}" opacity="0.6" font-family="sans-serif" font-size="12" font-weight="500">RESEARCH &amp; ANALYSIS REPORT</text>
      </svg>
    SVG
  end

  # --- 차트 스타일: 그래프 아이콘, 데이터 강조 ---
  def render_chart(s, ch, headline, _topic)
    lines = split_headline(headline, 11)
    # 가짜 막대 차트 배경
    bars = (1..8).map { |i| "<rect x=\"#{420 + i * 25}\" y=\"#{100 + rand(30..180)}\" width=\"18\" height=\"#{rand(60..200)}\" rx=\"3\" fill=\"#{s[:accent]}\" opacity=\"0.12\"/>" }.join
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <!-- 차트 배경 장식 -->
        #{bars}
        <!-- 추세선 -->
        <polyline points="30,280 120,240 200,260 300,200 400,180 500,150 600,120" fill="none" stroke="#{s[:accent]}" stroke-width="3" opacity="0.15"/>
        <!-- 채널명 -->
        <rect x="20" y="20" width="#{ch.length * 14 + 20}" height="30" rx="15" fill="#{s[:accent]}" opacity="0.9"/>
        <text x="#{30 + ch.length * 7}" y="41" text-anchor="middle" fill="white" font-family="sans-serif" font-size="13" font-weight="700">#{esc(ch)}</text>
        <!-- 배지 -->
        <rect x="#{ch.length * 14 + 52}" y="22" width="#{s[:badge].length * 11 + 12}" height="26" rx="4" fill="#{s[:badge_bg]}" opacity="0.7"/>
        <text x="#{ch.length * 14 + 58}" y="40" fill="white" font-family="sans-serif" font-size="11" font-weight="600">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 -->
        <text x="30" y="#{lines.size == 1 ? 200 : 175}" fill="#{s[:text_color]}" font-family="sans-serif" font-size="40" font-weight="900" letter-spacing="-1">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"30\" y=\"225\" fill=\"#{s[:text_color]}\" font-family=\"sans-serif\" font-size=\"40\" font-weight=\"900\" letter-spacing=\"-1\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 데이터 라벨 -->
        <text x="30" y="330" fill="#{s[:accent]}" opacity="0.5" font-family="monospace" font-size="11">DATA ANALYSIS #{Time.current.year}</text>
      </svg>
    SVG
  end

  # --- 다큐 스타일: 영화 포스터 느낌 ---
  def render_documentary(s, ch, headline, _topic)
    lines = split_headline(headline, 10)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <defs>
          <linearGradient id="docbg" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#{s[:bg]}" stop-opacity="1"/>
            <stop offset="50%" stop-color="#{s[:accent]}" stop-opacity="0.15"/>
            <stop offset="100%" stop-color="#{s[:bg]}" stop-opacity="1"/>
          </linearGradient>
        </defs>
        <rect width="640" height="360" fill="url(#docbg)"/>
        <!-- 상하 시네마 바 -->
        <rect width="640" height="40" fill="black"/>
        <rect y="320" width="640" height="40" fill="black"/>
        <!-- 배지 -->
        <rect x="24" y="8" width="#{s[:badge].length * 13 + 14}" height="24" rx="3" fill="#{s[:badge_bg]}"/>
        <text x="31" y="25" fill="white" font-family="sans-serif" font-size="12" font-weight="700">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 (영화 포스터 느낌) -->
        <text x="320" y="#{lines.size == 1 ? 195 : 170}" text-anchor="middle" fill="#{s[:text_color]}" font-family="sans-serif" font-size="44" font-weight="900" letter-spacing="-1">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"320\" y=\"225\" text-anchor=\"middle\" fill=\"#{s[:text_color]}\" font-family=\"sans-serif\" font-size=\"44\" font-weight=\"900\" letter-spacing=\"-1\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 채널명 -->
        <text x="320" y="348" text-anchor="middle" fill="#{s[:accent]}" font-family="sans-serif" font-size="13" font-weight="600" letter-spacing="3">#{esc(ch.upcase)}</text>
      </svg>
    SVG
  end

  # --- 친근한 스타일: 밝은 톤, 둥근 요소 ---
  def render_friendly(s, ch, headline, _topic)
    lines = split_headline(headline, 10)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
        <rect width="640" height="360" fill="#{s[:bg]}"/>
        <!-- 둥근 장식 원 -->
        <circle cx="540" cy="100" r="150" fill="#{s[:accent]}" opacity="0.08"/>
        <circle cx="80" cy="320" r="100" fill="#{s[:accent]}" opacity="0.06"/>
        <circle cx="600" cy="300" r="60" fill="#{s[:accent]}" opacity="0.1"/>
        <!-- 채널 아이콘 (둥근 이니셜) -->
        <circle cx="56" cy="42" r="24" fill="#{s[:accent]}"/>
        <text x="56" y="49" text-anchor="middle" fill="white" font-family="sans-serif" font-size="16" font-weight="800">#{esc(ch[0])}</text>
        <text x="90" y="49" fill="#{s[:text_color]}" font-family="sans-serif" font-size="16" font-weight="700">#{esc(ch)}</text>
        <!-- 배지 -->
        <rect x="#{90 + ch.length * 16 + 8}" y="28" width="#{s[:badge].length * 12 + 16}" height="26" rx="13" fill="#{s[:badge_bg]}" opacity="0.8"/>
        <text x="#{98 + ch.length * 16 + 8}" y="46" fill="white" font-family="sans-serif" font-size="12" font-weight="600">#{esc(s[:badge])}</text>
        <!-- 메인 텍스트 -->
        <text x="40" y="#{lines.size == 1 ? 210 : 185}" fill="#{s[:text_color]}" font-family="sans-serif" font-size="40" font-weight="800">#{esc(lines[0])}</text>
        #{lines[1] ? "<text x=\"40\" y=\"235\" fill=\"#{s[:accent]}\" font-family=\"sans-serif\" font-size=\"40\" font-weight=\"800\">#{esc(lines[1])}</text>" : ""}
        <!-- 하단 키워드 태그들 -->
        <rect x="40" y="290" width="60" height="24" rx="12" fill="#{s[:accent]}" opacity="0.2"/>
        <text x="70" y="306" text-anchor="middle" fill="#{s[:accent]}" font-family="sans-serif" font-size="11" font-weight="600">#분석</text>
        <rect x="110" y="290" width="70" height="24" rx="12" fill="#{s[:accent]}" opacity="0.2"/>
        <text x="145" y="306" text-anchor="middle" fill="#{s[:accent]}" font-family="sans-serif" font-size="11" font-weight="600">#쉽게설명</text>
      </svg>
    SVG
  end

  # --- 유틸리티 ---

  def split_headline(text, max_chars)
    return [text] if text.length <= max_chars
    mid = text.length / 2
    split_pos = text.rindex(/[\s,·:]/, mid) || mid
    [text[0...split_pos].strip, text[split_pos..].strip]
  end

  def esc(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;").gsub("'", "&apos;")
  end

  def dot_grid(color, opacity)
    dots = []
    (0..15).each { |x| (0..8).each { |y| dots << "<circle cx=\"#{x * 40 + 20}\" cy=\"#{y * 40 + 20}\" r=\"1.5\" fill=\"#{color}\" opacity=\"#{opacity}\"/>" } }
    dots.join("\n        ")
  end

  def grid_lines(color, opacity)
    lines = []
    (0..8).each { |i| lines << "<line x1=\"0\" y1=\"#{i * 45}\" x2=\"640\" y2=\"#{i * 45}\" stroke=\"#{color}\" stroke-width=\"0.5\" opacity=\"#{opacity}\"/>" }
    (0..16).each { |i| lines << "<line x1=\"#{i * 40}\" y1=\"0\" x2=\"#{i * 40}\" y2=\"360\" stroke=\"#{color}\" stroke-width=\"0.5\" opacity=\"#{opacity}\"/>" }
    lines.join("\n        ")
  end
end
