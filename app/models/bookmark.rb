# frozen_string_literal: true

# 사용자가 리포트를 '내 기록'에 저장하는 북마크
class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :fact_check

  validates :user_id, presence: true
  validates :fact_check_id, presence: true, uniqueness: { scope: :user_id }
end
