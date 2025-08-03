# frozen_string_literal: true

module Tobias
  class Container
    def initialize(code)
      @code = code
      @queries = {}

      eval(code, binding, __FILE__, __LINE__)
    end

    def queries
      @queries
    end

    def query(name, &block)
      @queries[name] = block
    end
  end
end
