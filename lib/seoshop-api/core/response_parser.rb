require 'typhoeus/adapters/faraday'
require 'faraday_middleware/response_middleware'

module Seoshop
  class ResponseParser < Faraday::Response::Middleware
    def call(env)
      # "env" contains the request
      @app.call(env).on_complete do
        body = false
        if env[:status] == 200
          body = env[:response].body.response || env[:response].body
        elsif env[:status] == 401
          raise Seoshop::ResponseParser::HTTPUnauthorized.new 'invalid Seoshop credentials'
        elsif env[:status] == 403
          raise env[:response].body.message
        elsif env[:status] == 404
          raise Seoshop::ResponseParser::HTTPNotFound.new env[:response].body.message
        elsif env[:status] == 429
          rate_limits = env[:response_headers]['X-RateLimit-Remaining'].split('/')
          rate_limits_reset = env[:response_headers]['X-RateLimit-Reset'].split('/')
          seconds = rate_limits_reset[0] if rate_limits[0] == '-1'
          seconds = rate_limits_reset[1] if rate_limits[1] == '-1'
          seconds = rate_limits_reset[2] if rate_limits[2] == '-1'
          raise Seoshop::ResponseParser::RateLimit.new "RateLimit reset in #{seconds} seconds"
        elsif env[:response] && env[:response].body && env[:response].body.status
          body = env[:response].body.status
        end
        env[:body] = body
      end
    end
  end

  #
  # Response middleware that decodes the response body from JSON.
  #
  class ParseOj < FaradayMiddleware::ResponseMiddleware
    dependency do
      require 'oj' unless defined?(::Oj)
    end

    define_parser do |body|
      begin
        ::Oj.load(body, mode: :compat) unless body.strip.empty?
      rescue Oj::ParseError => e
      end
    end
  end

  # Request middleware that encodes the body as JSON.
  #
  # Processes only requests with matching Content-type or those without a type.
  # If a request doesn't have a type but has a body, it sets the Content-type
  # to JSON MIME-type.
  #
  # Doesn't try to encode bodies that already are in string form.
  class EncodeOj < Faraday::Middleware
    CONTENT_TYPE = 'Content-Type'.freeze
    MIME_TYPE    = 'application/json'.freeze

    dependency do
      require 'oj' unless defined?(::Oj)
    end

    def call(env)
      match_content_type(env) do |data|
        env[:body] = encode data
      end
      @app.call env
    end

    def encode(data)
      ::Oj.dump data
    end

    def match_content_type(env)
      if process_request?(env)
        env[:request_headers][CONTENT_TYPE] ||= MIME_TYPE
        yield env[:body] unless env[:body].respond_to?(:to_str)
      end
    end

    def process_request?(env)
      type = request_type(env)
      has_body?(env) and (type.empty? or type == MIME_TYPE)
    end

    def has_body?(env)
      body = env[:body] and !(body.respond_to?(:to_str) and body.empty?)
    end

    def request_type(env)
      type = env[:request_headers][CONTENT_TYPE].to_s
      type = type.split(';', 2).first if type.index(';')
      type
    end

    class Seoshop::ResponseParser::RateLimit < Exception; end
    class Seoshop::ResponseParser::HTTPUnauthorized < Exception; end
    class Seoshop::ResponseParser::HTTPNotFound < Exception; end
  end
end

Faraday.register_middleware :response, oj: Seoshop::ParseOj
Faraday.register_middleware :request, oj: Seoshop::EncodeOj