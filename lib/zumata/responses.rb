module Zumata

  class GenericResponse
    attr_reader :context, :code, :body

    def initialize res
      @context = res[:context]
      @code = res[:code]
      @body = res[:body]
    end
  end

end