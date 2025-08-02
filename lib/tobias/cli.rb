# frozen_string_literal: true

module Tobias
  class CLI < Thor
    include ActiveSupport::NumberHelper

    def self.exit_on_failure?
      true
    end

    desc "profile SCRIPT", "profile"
    option :database_url, type: :string, required: true
    def profile(script)
      database = Sequel.connect(options[:database_url])
      database.loggers << Logger.new(nil)
      database.extension :pg_json

      values = [
        "64kB",
        "1MB",
        "4MB",
        "8MB",
        "16MB",
        "32MB",
        "64MB",
        "128MB",
        "256MB",
        "512MB",
        "1GB",
        "2GB",
        "4GB",
        "8GB",
      ]

      code = File.read("scripts/#{script}.rb")

      values.each do |value|
        database.transaction do
          database.run("SET LOCAL work_mem = '#{value}'")

          eval(code, binding, script)

          @queries.each do |name, block|
            database.select(Sequel.function(:pg_stat_reset)).first

            query = instance_eval(&block)

            10.times do
              query.all
            end

            stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

            puts "--------------------------------"
            puts "query: #{name}"
            puts "work_mem: #{value}"

            if stats[:temp_files] > 0 || stats[:temp_bytes] > 0
              puts "Not enough work_mem"
              puts "temp_files: #{stats[:temp_files]}"
              puts "temp_bytes: #{stats[:temp_bytes]}"
            else
              puts "Enough work_mem for #{name}"
            end
            puts "--------------------------------"

            # puts database.fetch("EXPLAIN (ANALYZE, BUFFERS, VERBOSE) #{query.sql}").all
          end

        end
      end
      # select pg_stat_reset();
      # select * from pg_stat_database where datname = current_database();
      # puts database.fetch("SELECT 1").first
    end

    private

    def query(name, &block)
      @queries ||= {}
      @queries[name] = block
    end

  end
end
