# frozen_string_literal: true

module Tobias
  class CLI < Thor
    include ActiveSupport::NumberHelper

    def self.exit_on_failure?
      true
    end

    desc "profile SCRIPT", "profile"
    option :database_url, type: :string, required: true
    option :iterations, type: :numeric, default: 100
    def profile(script)
      database = Sequel.connect(options[:database_url])
      database.loggers << Logger.new(nil)
      database.extension :pg_json

      if File.exist?(script)
        code = File.read(script)
      else
        raise "Script not found at: #{script}"
      end

      WorkMem.all.each do |value|
        database.transaction do
          database.run("SET LOCAL work_mem = '#{value.to_sql}'")

          eval(code, binding, script)

          @queries.each do |name, block|
            database.select(Sequel.function(:pg_stat_reset)).first

            query = instance_eval(&block)
            times = []

            options[:iterations].to_i.times do
              time = Benchmark.realtime do
                database.run(query.sql)
              end
              times << time
            end

            stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

            puts "--------------------------------"
            puts "query: #{name}"
            puts "work_mem: #{value.to_sql}"
            puts "clock time (mean): #{times.mean.round(2)}"
            puts "clock time (95%): #{times.percentile(95).round(2)}"

            if stats[:temp_files] > 0 || stats[:temp_bytes] > 0
              puts "Not enough work_mem"
              puts "temp_files: #{stats[:temp_files]}"
              puts "temp_bytes: #{stats[:temp_bytes]}"
            else
              puts "No temporary files written."
              puts "Current work_mem: '#{value.to_sql}' is sufficient."
              return
            end
            puts "--------------------------------"
          end
        end
      end
    end

    private

    def query(name, &block)
      @queries ||= {}
      @queries[name] = block
    end

  end
end
