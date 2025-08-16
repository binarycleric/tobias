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
      @helpers = Module.new

      eval(code, binding, __FILE__, __LINE__)
    end

    module DefaultHelpers
      def run_parallel(list, &block)
        list.each do |l|
          fork do
            Sequel::DATABASES.each(&:disconnect)
            block.call(l)
          end
        end

        Sequel::DATABASES.each(&:disconnect)
        Process.waitall
      end

      def download_from_hugging_face(repo, local_dir="/tmp/#{repo}")
        `hf download #{repo} --repo-type=dataset --local-dir #{local_dir}`
      end
    end

    def run_setup(context)
      run_action(@setup, context)
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
      helpers = @helpers

      context.class_eval do
        include DefaultHelpers
        include helpers

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
