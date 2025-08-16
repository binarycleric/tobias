# frozen_string_literal: true

module Tobias
  class Container
    def initialize(code)
      @code = code
      @queries = Concurrent::Hash.new
      @sql = Concurrent::Hash.new
      @options = Concurrent::Hash.new
      @setup = Proc.new { }
      @teardown = Proc.new { }
      @load_data = Proc.new { }

      eval(code, binding, __FILE__, __LINE__)
    end

    def run_setup(context)
      run_action(@setup, context)
    end

    def run_load_data(context)
      Etc.nprocessors.times do
        fork do
          context.disconnect
          run_action(@load_data, context)
        end
      end

      context.disconnect
      Process.waitall
    end

    def run_query(query, context)
      sql = if query.is_a?(String)
               query
             else
               run_action(query, context).sql
             end

      context.run(sql)
    end

    def run_teardown(context)
      run_action(@teardown, context)
    end

    def run_action(action, context)
      options = Struct.new(*@options.keys).new(*@options.values)
      context.class_eval do
        def options=(new_options)
          @options = new_options
        end

        def options
          @options
        end
      end

      context.options = options
      context.instance_eval(&action)
    end

    def queries
      @queries
    end

    def option(name, default = nil, &block)
      @options[name] = block || default
    end

    def setup(&block)
      @setup = block
    end

    def teardown(&block)
      @teardown = block
    end

    def load_data(&block)
      @load_data = block
    end

    def query(name, sql = nil, &block)
      @queries[name] = sql || block
    end
  end
end
