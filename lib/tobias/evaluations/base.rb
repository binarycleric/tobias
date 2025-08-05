# frozen_string_literal: true

class MarkdownTableBorder < TTY::Table::Border
  def_border do
    left         "|"
    center       "|"
    right        "|"
    bottom       " "
    bottom_mid   " "
    bottom_left  " "
    bottom_right " "
  end
end

module Tobias
  module Evaluations
    Result = Struct.new(:name, :value, :times, keyword_init: true) do
      def sample_count
        times.count
      end

      def average_time
        times.mean
      end

      def p99_time
        times.percentile(99)
      end
    end

    class Base
      attr_reader :database, :container, :options

      def initialize(database, container, options)
        @database = database
        @container = container
        @options = options
      end

      def run(&block)
        results = Concurrent::Array.new

        container.queries.each do |name, query|
          results << run_each(name, query)
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