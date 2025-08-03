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
    def profile(script)
      database = Sequel.connect(options[:database_url])
      database.loggers << Logger.new(nil)
      database.extension :pg_json

      if File.exist?(script)
        code = File.read(script)
      else
        raise "Script not found at: #{script}"
      end

      container = Container.new(code)
      max_value = nil

      container.queries.each do |name, block|
        work_mem = Evaluation.new(database).run(options, &block)

        if max_value.nil? || work_mem > max_value
          max_value = work_mem
        end

        puts "#{name}:\t**should** run with #{work_mem.to_sql} of work_mem."
      end

      puts "\n\n"
      puts "To run the queries with the recommended work_mem, run:\n"
      puts "\tSET work_mem = '#{max_value.to_sql}';"
    end
  end
end
