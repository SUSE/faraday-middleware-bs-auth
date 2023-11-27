# frozen_string_literal: true

module Faraday
  module Middlewares
    module BuildService
      class MissingCredentialsError < BaseError; end
    end
  end
end
