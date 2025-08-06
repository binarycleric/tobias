# frozen_string_literal: true

module Tobias
  class CLI < Thor
    include ActiveSupport::NumberHelper

    def self.exit_on_failure?
      true
    end

    desc "profile SCRIPT", "profile"
    option :database_url, type: :string, required: true
    option :iterations, type: :numeric, default: 10
    option :debug, type: :boolean, default: false
    def profile(script)
      database = Sequel.connect(options[:database_url])
      database.loggers << Logger.new(STDERR) if options[:debug]
      database.extension :pg_json

      if File.exist?(script)
        code = File.read(script)
      else
        raise "Script not found at: #{script}"
      end

      container = Container.new(code)
      results = {}

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias is thinking...
      MARKDOWN
      puts parsed

      thinking_time = Benchmark.realtime do
        results = Evaluations.run(database, container, options)
      end

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias has sent you a new message

        I thought about your queries for precisely #{thinking_time.round(2)} seconds and here is what I recommend:

        #{results.join("\n")}

        Regards,
        ~ Tobias
      MARKDOWN

      puts parsed
    end
  end
end
