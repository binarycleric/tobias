# frozen_string_literal: true

module Tobias
  class CLI < Thor
    include ActiveSupport::NumberHelper

    def self.exit_on_failure?
      true
    end

    desc "recommend", "recommend a work_mem setting for a database"
    option :database_url, type: :string, required: true
    option :debug, type: :boolean, default: false
    def recommend
      database = Sequel.connect(options[:database_url])
      database.extension :pgvector
      database.loggers << Logger.new(STDERR) if options[:debug]

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias is thinking...
      MARKDOWN
      puts parsed

      work_mem = Tobias::WorkMem.valid_for(database).sort_by(&:amount).reverse.first

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias has sent you a new message

        I've reviewed your database by analyzing your shared buffers and connection limits and
        recommend setting `work_mem` to `#{work_mem.to_sql}`. To apply my recommendation, run the following SQL:

        ```sql
        ALTER SYSTEM SET work_mem = '#{work_mem.to_sql}';
        SELECT pg_reload_conf();
        ```

        Regards,
        ~ Tobias
      MARKDOWN
      puts parsed
    end

    desc "profile SCRIPT", "profile"
    option :database_url, type: :string, required: true
    option :debug, type: :boolean, default: false
    def profile(script)
      database = Sequel.connect(options[:database_url], max_connections: Etc.nprocessors + 2)
      database.loggers << Logger.new(STDERR) if options[:debug]
      database.extension :pg_json
      database.extension :pgvector

      if File.exist?(script)
        code = File.read(script)
      else
        raise "Script not found at: #{script}"
      end

      container = Container.new(code, database)
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
