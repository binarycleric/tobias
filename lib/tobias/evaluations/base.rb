# frozen_string_literal: true

module Tobias
  module Evaluations
    class Base
      attr_reader :database, :container

      def initialize(database, container)
        @database = database
        @container = container
      end

      def run(options, &block)
        results = {}

        container.queries.each do |name, query|
          results.merge!(run_each(name, query, options))
        end

        to_markdown(results)
      end

      def run_each(query, options)
        raise NotImplementedError
      end

      def to_markdown(results)
        raise NotImplementedError
      end
    end
  end
end