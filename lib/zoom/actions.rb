# frozen_string_literal: true

module Zoom
  module Actions
    def self.extract_path_keys(path)
      path.scan(/:\w+/).map { |match| match[1..].to_sym }
    end

    def self.parse_path(path, path_keys, params)
      parsed_path = path.dup
      path_keys.each do |key|
        value        = params[key].to_s
        parsed_path  = parsed_path.sub(":#{key}", value)
      end
      parsed_path
    end

    def self.make_request(client, method, parsed_path, params, base_uri)
      request_options = { headers: client.request_headers }
      request_options[:base_uri] = base_uri if base_uri
      case method
      when :get
        request_options[:query] = params
      when :post, :put, :patch
        request_options[:body] = params.to_json
      end
      client.class.public_send(method, parsed_path, **request_options)
    end

    [:get, :post, :patch, :put, :delete].each do |method|
      define_method(method) do |name, path, options={}|
        required, permitted, base_uri = options.values_at :require, :permit, :base_uri
        required = Array(required) unless required.is_a?(Hash)
        permitted = Array(permitted) unless permitted.is_a?(Hash)

        define_method(name) do |*args|
          path_keys = Zoom::Actions.extract_path_keys(path)
          params = Zoom::Params.new(Utils.extract_options!(args))
          parsed_path = Zoom::Actions.parse_path(path, path_keys, params)
          params = params.require(path_keys) unless path_keys.empty?
          params_without_required = required.empty? ? params : params.require(required)
          params_without_required.permit(permitted) unless permitted.empty?
          response = Zoom::Actions.make_request(self, method, parsed_path, params, base_uri)
          Utils.parse_response(response)
        end
      end
    end
  end
end
