# frozen_string_literal: true

# @TASK P3-R3-T1 - ChannelTag 모델 테스트
# @TEST test/models/channel_tag_test.rb
require "test_helper"

class ChannelTagTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "tag-model-test@example.com", user_type: :b2c)
    @channel = Channel.create!(youtube_channel_id: "UC_tag_model_test", name: "Tag Test Channel")
  end

  # --- validation 테스트 ---

  test "모든 필수 필드가 있으면 유효하다" do
    tag = ChannelTag.new(channel: @channel, tag_name: "정치", created_by: @user.id)
    assert tag.valid?
  end

  test "tag_name 이 없으면 유효하지 않다" do
    tag = ChannelTag.new(channel: @channel, tag_name: nil, created_by: @user.id)
    assert_not tag.valid?
    assert_includes tag.errors[:tag_name], "can't be blank"
  end

  test "channel_id 가 없으면 유효하지 않다" do
    tag = ChannelTag.new(channel: nil, tag_name: "정치", created_by: @user.id)
    assert_not tag.valid?
    assert_includes tag.errors[:channel_id], "can't be blank"
  end

  test "created_by 가 없으면 유효하지 않다" do
    tag = ChannelTag.new(channel: @channel, tag_name: "정치", created_by: nil)
    assert_not tag.valid?
    assert_includes tag.errors[:created_by], "can't be blank"
  end

  test "같은 채널에 같은 tag_name 은 중복 생성할 수 없다" do
    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)

    duplicate = ChannelTag.new(channel: @channel, tag_name: "정치", created_by: @user.id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_name], "has already been taken"
  end

  test "다른 채널에는 같은 tag_name 을 사용할 수 있다" do
    other_channel = Channel.create!(youtube_channel_id: "UC_tag_other", name: "Other Channel")

    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    tag2 = ChannelTag.new(channel: other_channel, tag_name: "정치", created_by: @user.id)
    assert tag2.valid?
  end

  # --- association 테스트 ---

  test "channel 연관이 존재한다" do
    tag = ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    assert_equal @channel, tag.channel
  end

  test "creator 연관이 존재한다" do
    tag = ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    assert_equal @user, tag.creator
  end

  # --- scope 테스트 ---

  test "by_channel 스코프는 특정 채널의 태그만 반환한다" do
    other_channel = Channel.create!(youtube_channel_id: "UC_tag_scope_test", name: "Scope Channel")

    tag1 = ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    tag2 = ChannelTag.create!(channel: other_channel, tag_name: "경제", created_by: @user.id)

    results = ChannelTag.by_channel(@channel.id)
    assert_includes results, tag1
    assert_not_includes results, tag2
  end

  test "by_creator 스코프는 특정 사용자의 태그만 반환한다" do
    other_user = User.create!(email: "tag-other@example.com", user_type: :b2c)

    tag1 = ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    tag2 = ChannelTag.create!(channel: @channel, tag_name: "경제", created_by: other_user.id)

    results = ChannelTag.by_creator(@user.id)
    assert_includes results, tag1
    assert_not_includes results, tag2
  end
end
