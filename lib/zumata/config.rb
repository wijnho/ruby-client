module Zumata
  class << self
    attr_accessor :configuration
  end
 
  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
 
  class Configuration
    attr_accessor :api_url, :api_key
 
    def initialize
      @api_url = ''
      @api_key = nil
    end
  end
end

