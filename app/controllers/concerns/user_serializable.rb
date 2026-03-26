# frozen_string_literal: true

# @TASK P1-R1-T1 - 사용자 JSON 직렬화 공통 모듈
# @SPEC specs/domain/resources.yaml#users
# AuthController와 UsersController에서 공통으로 사용하는
# 사용자 응답 포맷을 정의한다.
module UserSerializable
  extend ActiveSupport::Concern

  private

  # 사용자 응답 JSON 포맷
  # 필드: id, email, name, user_type, created_at
  def user_response(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      user_type: user.user_type,
      created_at: user.created_at
    }
  end
end
