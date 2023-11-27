# frozen_string_literal: true

require "faraday"
require "http-cookie"

module Faraday
  module Middlewares
    module BuildService
      class Authentication < Faraday::Middleware
        include BuildService::HttpHelpers

        # @param env [Faraday::Env]
        # @param credentials [Hash]
        def initialize(app, credentials: {})
          super(app)

          @username = credentials[:username]
          @password = credentials[:password]
          @ssh_key = credentials[:ssh_key]

          reset!
        end

        def reset!
          @cookie_jar = ::HTTP::CookieJar.new
          @authorization = nil
        end

        # @param env [Faraday::Env]
        def call(env)
          request_body = env[:body]
          super(env)
        rescue BuildService::RetryWithAuthError
          # after failure env[:body] is set to the response body
          # see https://github.com/lostisland/faraday-retry/blob/main/lib/faraday/retry/middleware.rb
          env[:body] = request_body
          # retry only once
          super(env)
        end

        # @param env [Faraday::Env]
        def on_request(env)
          # If we have a cookie, use it and skip setting any other header.
          if (cookie = @cookie_jar.cookies(env.url) && cookie&.any?)
            env.request_headers["cookie"] = ::HTTP::Cookie.cookie_value(cookie)
            return
          end

          env.request_headers["Authorization"] = @authorization if @authorization
        end

        # @param env [Faraday::Env]
        def on_complete(env)
          # If we have get cookie, we just save it, nothing else to do.
          if (cookie = env[:response_headers]["set-cookie"])
            @cookie_jar.parse(cookie, env[:url]) and return
          end

          # if there's no challenge response, means we're good
          return unless env[:response_headers]["www-authenticate"]

          challenges = parse_authorization_header(env[:response_headers]["www-authenticate"])
          # If there's a challenge response AND we did authorization, then we failed.
          # Stop here and let the failure bubble up.
          return if @authorization

          # Do the authorization challenges
          challenges.each do |type, details|
            next do_basic_auth!(env, details) if type.to_s.casecmp("basic").zero?
            next do_signature_auth!(env, details) if type.to_s.casecmp("signature").zero?

            raise UnknownChallengeError.new("Unknown challenge #{type}: #{details.inspect}")
          end

          # Signal to #call that we need to retry the request.
          raise BuildService::RetryWithAuthError.new("Retry!")
        end

        # @param env [Faraday::Env]
        # @param _details [Hash]
        def do_basic_auth!(_env, _details)
          raise MissingCredentialsError.new("Missing Username / Password") unless @username || @password

          # Build an HTTP Basic Auth header
          value = Base64.encode64([@username, @password].join(":"))
          value.delete!("\n")
          @authorization = "Basic #{value}"
        end

        # @param env [Faraday::Env]
        # @param _details [Hash]
        def do_signature_auth!(env, details)
          raise MissingCredentialsError.new("Missing Username / SSH Key") unless @username || @ssh_key

          # Build an HTTP Signature Auth header
          payload = SshSigner.new(details, env[:response_headers], credentials: {
            username: @username,
            password: @password,
            ssh_key: @ssh_key
          }).generate
          @authorization = "Signature #{payload}"
        end
      end
    end
  end
end
