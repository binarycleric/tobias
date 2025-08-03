# frozen_string_literal: true

module Tobias
  class Evaluation
    attr_reader :database

    def initialize(database)
      @database = database
    end

    def run(options, &block)
      WorkMem.all.each do |value|
        database.transaction do
          database.run("SET LOCAL work_mem = '#{value.to_sql}'")
          database.select(Sequel.function(:pg_stat_reset)).first
          database.instance_eval(&block)

          query = database.instance_eval(&block)
          options[:iterations].to_i.times do
            database.run(query.sql)
          end

          stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

          if stats[:temp_files] == 0 && stats[:temp_bytes] == 0
            return value
          end
        end
      end

      raise "No work_mem found."
    end
  end
end