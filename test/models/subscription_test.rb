# frozen_string_literal: true

# @TASK P1-R2-T1 - Subscription 모델 테스트
# @TEST test/models/subscription_test.rb
require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "subscriber@example.com", user_type: :b2c)
    @subscription = Subscription.create!(
      user: @user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current,
      expires_at: 30.days.from_now
    )
  end

  # --- 연관 관계 ---

  test "user 연관 관계가 존재한다" do
    assert_respond_to @subscription, :user
    assert_equal @user, @subscription.user
  end

  # --- 유효성 검사 ---

  test "user_id가 없으면 유효하지 않다" do
    subscription = Subscription.new(plan_type: :b2c_basic, status: :active)
    assert_not subscription.valid?
    assert_includes subscription.errors[:user_id], "can't be blank"
  end

  test "plan_type이 없으면 유효하지 않다" do
    subscription = Subscription.new(user: @user, status: :active)
    # plan_type은 default: 0 이므로 integer 컬럼에서는 nil이 아님
    # 명시적으로 nil을 설정해야 검증 실패
    subscription.plan_type = nil
    assert_not subscription.valid?
  end

  test "status가 없으면 유효하지 않다" do
    subscription = Subscription.new(user: @user, plan_type: :b2c_basic)
    subscription.status = nil
    assert_not subscription.valid?
  end

  # --- Enum ---

  test "plan_type enum 값이 올바르게 설정된다" do
    assert @subscription.b2c_basic?

    @subscription.plan_type = :b2c_premium
    assert @subscription.b2c_premium?

    @subscription.plan_type = :b2b_standard
    assert @subscription.b2b_standard?

    @subscription.plan_type = :b2b_enterprise
    assert @subscription.b2b_enterprise?
  end

  test "status enum 값이 올바르게 설정된다" do
    assert @subscription.active?

    @subscription.status = :canceled
    assert @subscription.canceled?

    @subscription.status = :expired
    assert @subscription.expired?
  end

  # --- Scope ---

  test "active 스코프는 활성 구독만 반환한다" do
    canceled_sub = Subscription.create!(
      user: @user,
      plan_type: :b2c_premium,
      status: :canceled,
      started_at: Time.current
    )

    active_subs = Subscription.active
    assert_includes active_subs, @subscription
    assert_not_includes active_subs, canceled_sub
  end

  test "by_user 스코프는 특정 사용자의 구독만 반환한다" do
    other_user = User.create!(email: "other@example.com", user_type: :b2c)
    other_sub = Subscription.create!(
      user: other_user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current
    )

    user_subs = Subscription.by_user(@user.id)
    assert_includes user_subs, @subscription
    assert_not_includes user_subs, other_sub
  end

  test "expiring_soon 스코프는 곧 만료되는 구독을 반환한다" do
    # 5일 후 만료 → 7일 이내이므로 포함
    soon_sub = Subscription.create!(
      user: @user,
      plan_type: :b2c_premium,
      status: :active,
      started_at: Time.current,
      expires_at: 5.days.from_now
    )

    expiring = Subscription.expiring_soon(7)
    assert_includes expiring, soon_sub
  end

  # --- 비즈니스 로직 ---

  test "currently_active?는 활성이고 만료되지 않은 구독에 true를 반환한다" do
    assert @subscription.currently_active?
  end

  test "currently_active?는 만료된 구독에 false를 반환한다" do
    @subscription.update!(expires_at: 1.day.ago)
    assert_not @subscription.currently_active?
  end

  test "currently_active?는 취소된 구독에 false를 반환한다" do
    @subscription.update!(status: :canceled)
    assert_not @subscription.currently_active?
  end

  test "currently_active?는 expires_at이 nil이면 활성으로 간주한다" do
    @subscription.update!(expires_at: nil)
    assert @subscription.currently_active?
  end

  test "expired?는 만료 시간이 지난 구독에 true를 반환한다" do
    @subscription.update!(expires_at: 1.hour.ago)
    assert @subscription.past_expiry?
  end

  test "expired?는 아직 만료되지 않은 구독에 false를 반환한다" do
    assert_not @subscription.past_expiry?
  end

  test "cancel!은 구독 상태를 canceled로 변경한다" do
    @subscription.cancel!
    assert @subscription.canceled?
  end

  test "이미 취소된 구독은 cancel! 호출 시 에러를 발생시킨다" do
    @subscription.cancel!
    assert_raises(ActiveRecord::RecordInvalid) { @subscription.cancel! }
  end
end
