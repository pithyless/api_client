# Faraday for making requests
require 'faraday'

module ApiClient

  module Connection

    class Basic < Abstract

      def create_handler
        # Create and memoize the connection object
        # The empty block is necessary as we don't want Faraday to
        # initialize itself, we build our own stack in finalize_handler
        @handler = Faraday.new(@endpoint, @options[:faraday] || {})  do end
        finalize_handler
      end

      def finalize_handler
        @handler.use     Middlewares::Request::Logger, ApiClient.logger if ApiClient.logger
        @handler.use     Faraday::Request::UrlEncoded
        @handler.adapter Faraday.default_adapter
      end

      #### ApiClient::Connection::Abstract#get
      # Performs a GET request
      # Accepts three parameters:
      #
      # * path - the path the request should go to
      # * data - (optional) the query, passed as a hash and converted into query params
      # * headers - (optional) headers sent along with the request
      #
      def get(path, data = {}, headers = {})
        exec_request(:get, path, data, headers)
      end

      #### ApiClient::Connection::Abstract#post
      # Performs a POST request
      # Accepts three parameters:
      #
      # * path - the path request should go to
      # * data - (optional) data sent in the request
      # * headers - (optional) headers sent along in the request
      #
      # This method automatically adds the application token header
      def post(path, data = {}, headers = {})
        exec_request(:post, path, data, headers)
      end

      #### ApiClient::Connection::Abstract#put
      # Performs a PUT request
      # Accepts three parameters:
      #
      # * path - the path request should go to
      # * data - (optional) data sent in the request
      # * headers - (optional) headers sent along in the request
      #
      # This method automatically adds the application token header
      def put(path, data = {}, headers = {})
        exec_request(:put, path, data, headers)
      end

      #### FS::Connection#delete
      # Performs a DELETE request
      # Accepts three parameters:
      #
      # * path - the path request should go to
      # * data - (optional) the query, passed as a hash and converted into query params
      # * headers - (optional) headers sent along in the request
      #
      # This method automatically adds the application token header
      def delete(path, data = {}, headers = {})
        exec_request(:delete, path, data, headers)
      end

      private

      def exec_request(method, path, data, headers)
        response = @handler.send(method, path, data, headers)
        request = {method: method, path: path, data: data}
        handle_response(request, response)
      rescue Faraday::Error::ConnectionFailed => e
        raise ApiClient::Errors::ConnectionFailed.new(e.message, request, response)
      end

      def handle_response(request, response)
        raise ApiClient::Errors::ConnectionFailed.new(request, response) unless response
        case response.status
          when 401
            raise ApiClient::Errors::Unauthorized.new(request, response)
          when 403
            raise ApiClient::Errors::Forbidden.new(request, response)
          when 404
            raise ApiClient::Errors::NotFound.new(request, response)
          when 400
            raise ApiClient::Errors::BadRequest.new(request, response)
          when 406
            raise ApiClient::Errors::Unsupported.new(request, response)
          when 409
            raise ApiClient::Errors::Conflict.new(request, response)
          when 422
            raise ApiClient::Errors::UnprocessableEntity.new(response.body, request, response)
          when 300..399
            raise ApiClient::Errors::Redirect.new(response['Location'], request, response)
          when 500..599
            raise ApiClient::Errors::ServerError.new(request, response)
          else
            response
        end
      end

    end
  end
end
