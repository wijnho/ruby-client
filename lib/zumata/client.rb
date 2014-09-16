require 'httparty'
require 'time'
require 'awesome_print'
require 'json'

VALID_STATUS_CODES = [200, 500]

module Zumata
  class Client
  	include HTTParty

    raise Zumata::ClientConfigError unless ENV["ZUMATA_API_URL"]
    base_uri ENV["ZUMATA_API_URL"]

    def initialize api_key
      @api_key = api_key
      @timeout = 600
    end


    # GET /search
  	def search_by_destination destination, opts={}

      q = { api_key: opts[:api_key] || @api_key,
            destination: destination,
            rooms: opts[:rooms] || 1,
            adults: opts[:adults] || 2,
            gzip: true,
            currency: opts[:currency] || "USD" }

      # smart defaults    
      q[:checkin]  = opts[:checkin] || (Time.now + 60*60*60*24).strftime("%m/%d/%Y")
      q[:checkout] = opts[:checkout] || (Time.now + 61*60*60*24).strftime("%m/%d/%Y")

      # optional
      q[:lang]     = opts[:lang] if opts[:lang]
      q[:timeout]  = opts[:timeout] if opts[:timeout]
      
      res = self.class.get("/search", query: q).response

      # todo - handle errors from search
      Zumata::GenericResponse.new(context: q, code: res.code.to_i, body: res.body)
    end


    # POST /book_property
    # internal: /book
    def book booking_key, guest, payment, opts={}

      # raise InvalidRequestError unless valid_guest_params?(guest)
      # raise InvalidRequestError unless valid_payment_params?(payment)
      
      body_params = { api_key: opts[:api_key] || @api_key,
                      booking_key: booking_key,
                      guest: guest,
                      payment: payment }
      
      res = self.class.post("/book", body: body_params.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: @timeout)

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