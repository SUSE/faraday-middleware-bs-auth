# frozen_string_literal: true

module Faraday
  module Middlewares
    module BuildService
      # Collection of low level HTTP Helpers
      module HttpHelpers
        # Convert a list of pairs into signature string format
        #
        # @param pairs   [Array of [String, String]] String pairs to format
        #
        # As per the last part of
        # https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12#section-2.3
        # the format is:
        #
        # header: value -- for static http headers
        def pairs_to_payload(pairs)
          pairs.map { |k, v| "#{k}: #{v}" }.join("\n")
        end

        # Convert a list of pairs into signature string format
        #
        # @param pairs   [Array of [String, String]] String pairs to format
        #
        # As per the last part of
        # https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12#section-2.3
        # the format is:
        #
        # header: value -- for static http headers
        def pairs_to_quoted_string(pairs)
          pairs.map do |key, value|
            value = value.to_s.gsub('"', '\\"') # escape inner quotes
            %(#{key}="#{value}")
          end.join(",")
        end

        # Parse an http header list into a ruby list. This is not a regexable (at
        # least not a simple regex can do it so far) since the quoted values can
        # have commas. Is written as a tokenizer for this reason.
        #
        # @param list_string [String] HTTP List string
        #
        # example input: 'Signature realm="Use your developer account",headers="(created)", Basic realm="somerealm"'
        #
        # example output: ['Signature realm="Use your developer account"', 'headers="(created)"', 'Basic realm="somerealm"']
        def parse_list_header(list_string)
          res = []
          part = ""
          escape = quote = false

          list_string.each_char do |char|
            # if in escape mode, add the escaped character and reset
            # the escape flag.
            if escape
              part += char
              escape = false
              next
            end

            # if in quote mode
            if quote
              case char
              # check for a escape sequence and skip the escape character
              when "\\"
                escape = true
                next
              # check a quote and disable quote mode
              when '"'
                quote = false
              end

              # add the character to the part but don't process anything further
              # quoted commas are meant to be kept as values
              part += char
              next
            end

            # in normal case
            case char
            # comma is a signal for a new item, save the current part & reset.
            when ","
              res << part
              part = ""
              next
            # quote enables quote mode
            when '"'
              quote = true
            end

            # add the character to the part
            part += char
          end

          # if there's any pending part, add it to the final result
          if part
            res << part
          end

          # strip the surrounding spaces & remove the empty items
          res.map(&:strip).reject(&:empty?)
        end

        # Parse an WWW-Authenticate Header a hash of challenges
        #
        # @param header [String] WWW-Authenticate Header
        #
        # The WWW-Authenticate grammar is defined in
        # https://datatracker.ietf.org/doc/html/rfc7235#section-4.1
        #
        # given this input: 'Signature realm="yourealm",headers="abcdef"'
        # it returns
        # { Signature: {realm: "yourealm", headers: "abcdef"} }
        #
        # This implementation is generic enough to get information about multiple
        # challenges as long as they're not the same.
        def parse_authorization_header(header)
          result = {}
          current_section = nil

          parse_list_header(header).each do |item|
            result[item] = nil and next unless item.include?("=")

            name, value = item.split("=", 2)

            if name.include?(" ")
              current_section, name = name.split(" ", 2)
            end

            if value[0] == value[-1] && value[0] == '"'
              value = unquote(value[1..])
            end

            (result[current_section.to_sym] ||= {})[name.to_sym] = value
          end

          result
        end

        # Remove quotes from string
        #
        # @param string [String] String to be unquoted
        def unquote(string)
          s = string.dup

          case string[0, 1]
          when "'", '"', "`"
            s[0] = ""
          end

          case string[-1, 1]
          when "'", '"', "`"
            s[-1] = ""
          end

          s
        end
      end
    end
  end
end
