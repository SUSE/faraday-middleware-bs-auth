# frozen_string_literal: true

require "open3"
module Faraday
  module Middlewares
    module BuildService
      class SshSigner
        include HttpHelpers
        # Initalizes the signer
        #
        # @param challenge_params   [Hash] WWW-Authenticate header parameters.
        # @param headers            [Hash] Request headers
        # @param credentials        [Hash] Credentials to sign the request
        #                                    Is expected to have :username & :ssh_key.
        # @param challenge_context  [String] Additional context headers for the challenge.
        #
        #     challenge_params keys are:
        #       :realm => The realm to perform authentication on.
        #       :headers => a string list of headers to be used.
        def initialize(challenge_params, headers, credentials: {}, challenge_context: {})
          @headers = headers
          @credentials = credentials
          # The challenge is formatted according to RFC7235 section 4.1
          # https://datatracker.ietf.org/doc/html/rfc7235#section-4.1
          # www-authenticate: 'Signature realm="Use your developer account",headers="(created)"'
          #
          # This signer does only process Signature challenge
          @challenge_params = challenge_params

          created = Time.now.to_i
          # funny tip: you can bucket requests into 5 min blocks and the signature
          # will still be constant & valid.
          # created = created - (created % 300)
          @challenge_context = {
            created: created
          }.update(challenge_context)

          # As per RFC Signing HTTP Messages draft-cavage-http-signatures-12 section
          # 2.3. At the very least `(created)` header (and `(request-target)` but Build
          # Service implementation doesn't include it) should be provided to the
          # signature string.

          # (created) represents a unix timestamp that must be provided into the
          # final signature for the server to validate.
        end

        # Generate Signature
        #
        # as per https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12#section-2.1
        #
        # a `signing_string` is created based on the headers that the challenge demands
        # the format for such signing_string (also referred as payload) is:
        #
        # (calculated header): %value%\n
        # host: your.host
        #
        # the \n is to show that a newline is needed there. Then this full string is
        # passed to the signing algorithm, in the build service case is:
        #
        # ssh-keygen -Y sign -f "%path-to-privk%" -n "%realm%" -q <<< "signing string"
        #
        # the result of that signature is in OpenSSH Signature format. Delimiters are
        # removed & newlines stripped.
        #
        # This final result along with the parameters used to generate the signature
        # are concatenated in an HTTP List format and returned to the caller to use.
        def generate
          # first listify the headers in the challenge. As the spec
          @challenge_params[:headers] ||= "(created)"

          headers = @challenge_params[:headers].split

          # Iterate through it to build the singing string
          payload_pairs = headers.map do |header|
            value = if header.include?("(")
              # if it's a calculated header (surrounded by parenthesis), look for it
              # in the challenge_context
              @challenge_context[header.tr("()", "").to_sym]
            else
              # else look for it in the given headers
              @headers[header]
            end

            [header, value]
          end

          # Build the signing string
          signing_string = pairs_to_payload(payload_pairs)

          # remove parenthesis from the headers to append to the signature parameters
          payload_pairs = payload_pairs.map do |key, value|
            key = key.tr("()", "")
            [key, value]
          end

          # sign with the provided realm (or empty if not present)
          signature = ssh_sign(signing_string, @challenge_params[:realm] || "", @credentials[:ssh_key])

          # Build all signature parameters
          signature_parameters = [
            ["keyId", @credentials[:username]],
            ["algorithm", "ssh"],
            ["signature", signature],
            ["headers", @challenge_params[:headers]],
            *payload_pairs
          ]

          # build the HTTP quoted list & return
          pairs_to_quoted_string(signature_parameters)
        end

        # Sign a given payload pertaining to a specific realm
        #
        # @param payload [String] Payload to sign
        # @param realm   [String] Realm or Purpose (see man ssh-keygen section -Y sign)
        # @param ssh_key [Hash] SSH Private key to use in the singing
        #
        # The SSH Privatekey will briefly be materialized as a file in the filesystem
        # for SSH to be able to pick it up and sign the payload.
        #
        # Then it'll be removed
        def ssh_sign(payload, realm, ssh_key)
          Tempfile.create("ssh-key", Rails.root.join("tmp/")) do |file|
            file.write(ssh_key)
            file.flush # force IO flush

            cmd = ["ssh-keygen", "-Y", "sign", "-f", file.path.to_s, "-q", "-n", realm]
            stdout, stderr, process_status = Open3.capture3({}, *cmd, stdin_data: payload)
            raise "cannot sign: #{stderr}" unless process_status.to_i.zero?

            # remove the surrounding --- blocks & join in one single line
            signature = stdout.split("\n").slice(1..-2).join.presence

            # this should never happen, ssh-keygen ALWAYS returns an armored format or fail
            unless signature
              raise "cannot sign: bad output"
            end

            signature
          end
        end
      end
    end
  end
end
