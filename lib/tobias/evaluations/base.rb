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
    Result = Struct.new(:name, :value, keyword_init: true) do
      def <=>(other)
        value <=> other.value
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

        container.run_setup(database)

        container.queries.each do |name, query|
          result = run_each(name, query)
          results << result if result
        end

        to_markdown(results)
      ensure
        container.run_teardown(database)
      end

      def run_each(query)
        raise NotImplementedError
      end

      def to_markdown(results)
        raise NotImplementedError
      end

      def render_table(headers:, body:)
        table = TTY::Table.new(header: headers)
        body.each do |row|
          table << row
        end

        table.render_with(MarkdownTableBorder)
      end
    end
  end
end