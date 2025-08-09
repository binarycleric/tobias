# frozen_string_literal: true

module Tobias
  class Container
    def initialize(code)
      @code = code
      @queries = Concurrent::Hash.new
      @sql = Concurrent::Hash.new
      @setup = Proc.new { }
      @teardown = Proc.new { }

      eval(code, binding, __FILE__, __LINE__)
    end

    def run_setup(context)
      context.instance_eval(&@setup)
    end

    def run_teardown(context)
      context.instance_eval(&@teardown)
    end

    def queries
      @queries
    end

    def setup(&block)
      @setup = block
    end

    def teardown(&block)
      @teardown = block
    end

    def query(name, sql = nil, &block)
      @queries[name] = sql || block
    end
  end
end
