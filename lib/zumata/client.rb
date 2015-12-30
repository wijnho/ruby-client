require 'httparty'
require 'time'
require 'awesome_print'
require 'json'

VALID_STATUS_CODES = [200, 500]

module Zumata
  class Client
    include HTTParty
    headers "Host" => @api_url
    headers "X-Api-Key" => @api_key
    def initialize opts={}
      raise Zumata::ClientConfigError.new("No API URL configured") if Zumata.configuration.nil? || Zumata.configuration.api_url == ''
      @api_url = Zumata.configuration.api_url
      @api_key = opts[:api_key] unless opts[:api_key].nil?
      @timeout = 600
    end

    def get_api_key
      @api_key || Zumata.configuration.api_key
    end

    # GET /search
    def search_by_destination destination, opts={}

      q = { api_key: opts[:api_key] || get_api_key,
            destination_id: destination,
            room_count: opts[:room_count] || 1,
            adult_count: opts[:adult_count] || 2,
            currency: opts[:currency] || "USD" }

      # smart defaults
      q[:check_in_date]  = opts[:check_in_date] || (Time.now + 60*60*60*24).strftime("%Y-%m-%d")
      q[:check_out_date] = opts[:check_out_date] || (Time.now + 61*60*60*24).strftime("%Y-%m-%d")

      # optional
      q[:lang]     = opts[:lang] if opts[:lang]
      q[:timeout]  = opts[:timeout] if opts[:timeout]
      q[:filter]   = opts[:filter] if opts[:filter]
      q[:child_count]   = opts[:child_count] if opts[:child_count]
      q[:source_market]   = opts[:source_market] if opts[:source_market]

      res = self.class.get("#{@api_url}/search", query: q).response

      # todo - handle errors from search
      Zumata::GenericResponse.new(context: q, code: res.code.to_i, body: res.body)
    end


    # POST /book_property
    # internal: /book
    def book booking_key, guest, payment, opts={}

      # raise InvalidRequestError unless valid_guest_params?(guest)
      # raise InvalidRequestError unless valid_payment_params?(payment)

      api_key = opts[:api_key] || get_api_key
      q_params = { api_key: api_key }
      body_params = { api_key: api_key,
                      booking_key: booking_key,
                      affiliate_key: opts[:affiliate_key],
                      guest: guest,
                      payment: payment }

      res = self.class.post("#{@api_url}/book", query: q_params, body: body_params.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: @timeout)

      status_code = res.code.to_i
      raise Zumata::GeneralError, res.body unless VALID_STATUS_CODES.include?(status_code)

      case status_code
      when 200
        return Zumata::GenericResponse.new(context: body_params, code: status_code, body: res.body)
      when 500
        begin
          parsed_json = JSON.parse(res.body)
          error_msg = parsed_json["status"][0]["error"]
        rescue JSON::ParserError, NoMethodError
          raise Zumata::GeneralError, res.body
        end
        Zumata::ErrorHelper.handle_type(error_msg)
      end

    end
  end
end
