# frozen_string_literal: true

module Faraday
  module Middlewares
    module BuildService
      class RetryWithAuthError < BaseError; end
    end
  end
end
