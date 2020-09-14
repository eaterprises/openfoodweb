# frozen_string_literal: true

module Spree
  module Core
    module ControllerHelpers
      def self.included(klass)
        klass.class_eval do
          include Spree::Core::ControllerHelpers::Common
          include Spree::Core::ControllerHelpers::Auth
          include Spree::Core::ControllerHelpers::RespondWithRenamed
          include Spree::Core::ControllerHelpers::Order
        end
      end
    end
  end
end
