# frozen_string_literal: true

# @TASK P0-T0.3 - 팩트체크 리포트 모델
# @TASK P2-R1-T1 - 팩트체크 모델 보강 (URL 검증, video_id 추출, scope 추가)
# @SPEC docs/planning/04-database-design.md#23-fact_checks-팩트체크-리포트
# 유튜브 영상에 대한 팩트체크 분석 결과를 관리하는 모델
class FactCheck < ApplicationRecord
  belongs_to :user
  belongs_to :channel
  has_many :claims, dependent: :destroy

  enum :status, { pending: 0, analyzing: 1, completed: 2, failed: 3 }

  # 유튜브 URL 검증 정규식 (youtube.com/watch, youtu.be 단축 URL 모두 지원)
  YOUTUBE_URL_REGEX = %r{
    \A
    https?://
    (?:www\.)?
    (?:youtube\.com/watch\?.*v=|youtu\.be/)
    [a-zA-Z0-9_-]+
  }x

  validates :user_id, :channel_id, presence: true
  validates :youtube_url, presence: true,
    format: { with: YOUTUBE_URL_REGEX, message: "올바른 유튜브 URL을 입력해 주세요." }

  # youtube_url이 설정되면 youtube_video_id를 자동 추출
  before_validation :extract_youtube_video_id, if: -> { youtube_url.present? }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :completed_checks, -> { where(status: :completed) }
  scope :by_status, ->(status) { where(status: status) }

  private

  # 유튜브 URL에서 11자리 영상 ID를 추출한다.
  # youtube.com/watch?v=VIDEO_ID 와 youtu.be/VIDEO_ID 형식을 모두 지원
  def extract_youtube_video_id
    return if youtube_url.blank?

    uri = URI.parse(youtube_url)

    self.youtube_video_id = if uri.host&.match?(/youtu\.be/)
      # 단축 URL: https://youtu.be/VIDEO_ID
      uri.path&.delete_prefix("/")
    elsif uri.host&.match?(/youtube\.com/)
      # 일반 URL: https://www.youtube.com/watch?v=VIDEO_ID
      params = URI.decode_www_form(uri.query || "").to_h
      params["v"]
    end
  rescue URI::InvalidURIError
    nil
  end
end
