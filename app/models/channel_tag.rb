# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 태그 모델
# @SPEC docs/planning/04-database-design.md#27-channel_tags-채널-태그-사용자-지정
# 사용자가 채널에 지정한 커스텀 태그를 관리하는 모델
class ChannelTag < ApplicationRecord
  belongs_to :channel
  belongs_to :creator, class_name: "User", foreign_key: :created_by

  validates :channel_id, :tag_name, :created_by, presence: true

  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :by_creator, ->(user_id) { where(created_by: user_id) }
end
