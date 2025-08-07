# frozen_string_literal: true

module Tobias
  class Container
    def initialize(code)
      @code = code
      @queries = Concurrent::Hash.new
      @sql = Concurrent::Hash.new

      eval(code, binding, __FILE__, __LINE__)
    end

    def queries
      @queries
    end

    def query(name, sql = nil, &block)
      @queries[name] = sql || block
    end
  end
end
