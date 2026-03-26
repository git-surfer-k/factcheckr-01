# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 태그 모델
# @TASK P3-R3-T1 - ChannelTag 모델 보강 (uniqueness 검증 추가)
# @SPEC docs/planning/04-database-design.md#27-channel_tags-채널-태그-사용자-지정
# 사용자가 채널에 지정한 커스텀 태그를 관리하는 모델
class ChannelTag < ApplicationRecord
  belongs_to :channel
  belongs_to :creator, class_name: "User", foreign_key: :created_by

  validates :channel_id, :created_by, presence: true
  # 같은 채널에 동일한 태그 이름은 중복 불가
  validates :tag_name, presence: true, uniqueness: { scope: :channel_id }

  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :by_creator, ->(user_id) { where(created_by: user_id) }
end
