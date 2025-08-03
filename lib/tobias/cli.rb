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

      work_mem = Evaluation.new(database).run(options) do
        eval(code, binding, script)
      end

      puts "This query should run with #{work_mem.to_sql} of work_mem."
      exit 0
    end
  end
end
