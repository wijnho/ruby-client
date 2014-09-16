module Zumata

  class ZumataError < StandardError; end

  class TestConfigError < ZumataError; end
  class ClientConfigError < ZumataError; end
  
  # Messages for non-200 responses
  class GeneralError < ZumataError; end
  class InvalidApiKeyError < ZumataError; end
  class InvalidBookingKeyError < ZumataError; end
  class TransactionError < ZumataError; end

  module ErrorHelper
    def self.handle_type message
      case message
      when "Invalid Api Key."
        raise InvalidApiKeyError, message
      when "Invalid/Expired Booking key"
        raise InvalidBookingKeyError, message
      when "Payment & Booking Transactions are not successful. Please contact us for more details."
        raise TransactionError, message
      else
        raise GeneralError, message
      end
    end
  end

end