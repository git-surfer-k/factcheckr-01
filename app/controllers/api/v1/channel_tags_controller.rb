# frozen_string_literal: true

# @TASK P3-R3-T1 - 채널 태그 API 컨트롤러
# @SPEC docs/planning/02-trd.md#채널-관리-API
module Api
  module V1
    # 채널에 사용자 지정 태그를 조회/추가하는 컨트롤러.
    # 채널 존재 여부를 먼저 검증한 후, 태그 목록 조회 및 생성을 처리한다.
    class ChannelTagsController < ApplicationController
      before_action :set_channel

      # GET /api/v1/channels/:channel_id/tags
      # 특정 채널에 등록된 태그 목록을 반환
      def index
        tags = @channel.channel_tags

        render json: {
          tags: tags.map { |tag| tag_response(tag) }
        }
      end

      # POST /api/v1/channels/:channel_id/tags
      # 채널에 새 태그를 추가 (created_by는 현재 사용자로 자동 설정)
      def create
        tag = @channel.channel_tags.build(
          tag_name: params[:tag_name],
          created_by: current_user.id
        )

        if tag.save
          render json: tag_response(tag), status: :created
        else
          render json: { detail: tag.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      # 채널을 찾고, 존재하지 않으면 404 반환
      def set_channel
        @channel = Channel.find_by(id: params[:channel_id])

        unless @channel
          render json: { detail: "채널을 찾을 수 없습니다." }, status: :not_found
        end
      end

      # 태그 응답 포맷
      def tag_response(tag)
        {
          id: tag.id,
          channel_id: tag.channel_id,
          tag_name: tag.tag_name,
          created_by: tag.created_by
        }
      end
    end
  end
end
