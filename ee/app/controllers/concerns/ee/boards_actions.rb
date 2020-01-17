# frozen_string_literal: true

module EE
  module BoardsActions
    extend ActiveSupport::Concern

    prepended do
      include ::MultipleBoardsActions
    end

    private

    def push_wip_limits
      push_frontend_feature_flag(:wip_limits, parent) if parent.feature_available?(:wip_limits)
    end
  end
end
