# frozen_string_literal: true

require "open3"

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

      def run_parallel(list = Etc.nprocessors.times, &block)
        db.disconnect

        Parallel.each(list, in_processes: Etc.nprocessors) do |item|
          instance_exec(item, &block)
        end
      end
    end

    def run_setup
      @database.run("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
      run_action(@setup)
    end

    def run_query(query)
      @database.run(run_action(query).sql)
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
      if sql.is_a?(String)
        @queries[name] = Proc.new { sql }
      else
        @queries[name] = block || Proc.new { raise "No SQL provided for query '#{name}'" }
      end
    end
  end
end
