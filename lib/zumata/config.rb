module Zumata
  class << self
    attr_accessor :configuration
  end
 
  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
 
  class Configuration
    attr_accessor :api_url
 
    def initialize
      @api_url = ''
    end
  end
end

