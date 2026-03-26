# frozen_string_literal: true

class PagesController < ActionController::Base
  include WebAuthenticatable

  protect_from_forgery with: :exception
  layout "application"

  RANKING_CATEGORIES = %w[정치 경제 사회 국제].freeze
  DEFAULT_PER_LOAD = 12
  MAX_LOAD_COUNT = 300

  def home
    @recent_checks = FactCheck.includes(:channel).where(status: :completed).order(created_at: :desc).limit(DEFAULT_PER_LOAD)
  end

  def ranking
    @categories = RANKING_CATEGORIES
    @selected_category = params[:category].presence
    @channels = @selected_category.present? ? Channel.by_category(@selected_category).ranked_by_trust : Channel.ranked_by_trust
  end

  def history
    redirect_to auth_path and return unless logged_in?
    load_paginated(current_web_user.bookmarked_fact_checks.includes(:channel), order: "bookmarks.created_at DESC")
  end

  def explore
    load_paginated(FactCheck.includes(:channel).where(status: :completed))
  end

  def settings
    redirect_to(auth_path) and return unless logged_in?
    @current_subscription = current_web_user.subscriptions.active.order(created_at: :desc).first
  end

  def auth
    redirect_to root_path and return if logged_in?
  end

  def analyze
    @fact_check_id = params[:id]
  end

  private

  # history/explore 공통 페이지네이션 로직
  def load_paginated(base_query, order: "created_at DESC")
    @load_count = [(params[:count] || DEFAULT_PER_LOAD).to_i, MAX_LOAD_COUNT].min
    @per_load = DEFAULT_PER_LOAD
    @fact_checks = base_query.order(order).limit(@load_count + 1).to_a
    @has_more = @fact_checks.length > @load_count
    @fact_checks = @fact_checks.first(@load_count)
    @total_count = @has_more ? base_query.count : @fact_checks.length
  end
end
