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
      work_mems = WorkMem.valid_for(database)
      results = {}

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias is thinking...
      MARKDOWN
      puts parsed

      thinking_time = Benchmark.realtime do
        container.queries.each do |name, block|
          work_mem = Evaluation.new(database, work_mems).run(options, &block)

          results[name] = work_mem
        end
      end

      parsed = TTY::Markdown.parse(<<~MARKDOWN)
        # @tobias has sent you a new message

        I thought about your queries for #{thinking_time.round(2)} seconds and here is what I recommend:

        | Query | Required work_mem |
        |-------|-------------------|
        #{results.map { |name, work_mem| "| #{name} | #{work_mem.to_sql} |" }.join("\n")}

        Your application will need to run with at least #{results.values.max.to_sql} of work_mem.

        To apply my recommendations, run the following SQL:

        ```sql
        SET work_mem = '#{results.values.max.to_sql}';
        ```

        Regards,
        ~ Tobias
      MARKDOWN

      puts parsed
    end
  end
end
