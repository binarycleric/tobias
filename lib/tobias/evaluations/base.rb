# frozen_string_literal: true

module Tobias
  module Evaluations
    class Base
      attr_reader :database, :container, :options

      def initialize(database, container, options)
        @database = database
        @container = container
        @options = options
      end

      def run(&block)
        results = {}

        container.queries.each do |name, query|
          results.merge!(run_each(name, query))
        end

        to_markdown(results)
      end

      def run_each(query)
        raise NotImplementedError
      end

      def to_markdown(results)
        raise NotImplementedError
      end
    end
  end
end