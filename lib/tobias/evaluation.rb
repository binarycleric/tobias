# frozen_string_literal: true

module Tobias
  class Evaluation
    def initialize(database)
      @database = database
    end

    def run(options, &block)
      WorkMem.all.each do |value|
        database.transaction do
          database.run("SET LOCAL work_mem = '#{value.to_sql}'")

          instance_eval(&block)

          @queries.each do |name, block|
            database.select(Sequel.function(:pg_stat_reset)).first

            query = database.instance_eval(&block)
            times = []

            options[:iterations].to_i.times do
              time = Benchmark.realtime do
                database.run(query.sql)
              end
              times << time
            end

            stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

            if stats[:temp_files] == 0 && stats[:temp_bytes] == 0
              return value
            end
          end
        end
      end
    end

    private

    attr_reader :database

    def query(name, &block)
      @queries ||= {}
      @queries[name] = block
    end
  end
end