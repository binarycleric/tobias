# frozen_string_literal: true

module Tobias
  class Container
    def initialize(code, database)
      @code = code
      @database = database
      @queries = Concurrent::Hash.new
      @sql = Concurrent::Hash.new
      @options = Concurrent::Hash.new
      @setup = Proc.new { }
      @teardown = Proc.new { }
      @load_data = Proc.new { }
      @helpers = Module.new

      eval(code, binding, __FILE__, __LINE__)
    end

    module DefaultHelpers
      def db
        @database
      end

      def run_parallel(list, &block)
        thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 2,
          max_threads: Etc.nprocessors,
          max_queue: 100
        )

        promises = list.map do |item|
          Concurrent::Promise.execute(executor: thread_pool) do
            block.call(item)
          end
        end

        promise = Concurrent::Promise.zip(*promises)

        loop do
          break if promise.fulfilled? || promise.rejected?
          sleep 0.1
        end
      end
    end

    def run_setup
      run_action(@setup)
    end

    def run_query(query)
      sql = if query.is_a?(String)
               query
             else
               run_action(query).sql
             end

      @database.run(sql)
    end

    def run_teardown
      run_action(@teardown)
    end

    def options
      Struct.new(*@options.keys).new(*@options.values)
    end

    def run_action(action)
      helpers = @helpers

      class_eval do
        include DefaultHelpers
        include helpers
      end

      instance_eval(&action)
    end

    def queries
      @queries
    end

    def option(name, default = nil, &block)
      @options[name] = block || default
    end

    def helpers(&block)
      @helpers.class_eval(&block) if block_given?
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
