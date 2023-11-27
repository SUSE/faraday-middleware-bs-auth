# frozen_string_literal: true

module Faraday
  module Middlewares
    module BuildService
      class UnknownChallengeError < BaseError; end
    end
  end
end
