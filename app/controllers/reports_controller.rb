# frozen_string_literal: true

class ReportsController < ActionController::Base
  include WebAuthenticatable

  protect_from_forgery with: :exception
  layout "application"

  def show
    @fact_check = FactCheck.includes({ claims: :news_sources }, :channel).find(params[:id])
    @claims = @fact_check.claims.ordered
    @channel = @fact_check.channel
    @all_news_sources = @claims.flat_map(&:news_sources).sort_by { |ns| -(ns.relevance_score || 0) }
    @bookmarked = current_web_user&.bookmarks&.exists?(fact_check_id: @fact_check.id) || false
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end
end
