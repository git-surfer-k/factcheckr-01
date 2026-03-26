# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 설정 Key-Value 모델
# @SPEC CLAUDE.md#관리자-페이지-구현
# 환경변수를 웹에서 관리할 수 있도록 DB에 저장하는 설정 모델.
# DB 값이 없으면 환경변수를 폴백으로 사용한다.
class AdminSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # 설정값 조회: DB → 환경변수 → 기본값 순서로 탐색
  def self.get(key, default = nil)
    find_by(key: key)&.value || ENV[key.to_s.upcase] || default
  end

  # 설정값 저장: 해당 key가 없으면 생성, 있으면 갱신
  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.update!(value: value)
  end

  # API 키를 마스킹하여 반환 (처음 4자만 표시, 나머지는 *)
  def masked_value
    return "" if value.blank?
    return value if value.length <= 4

    value[0..3] + ("*" * [value.length - 4, 20].min)
  end
end
