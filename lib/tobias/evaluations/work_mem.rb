# frozen_string_literal: true

module Tobias
  module Evaluations
    class WorkMem < Base

      def work_mems
        Tobias::WorkMem.valid_for(database)
      end

      def description
        "Optional work_mem settings"
      end

      def run_each(name, query, options)
        work_mems.each do |value|
          database.transaction do
            database.run("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
            database.run("SET LOCAL work_mem = '#{value.to_sql}'")
            database.select(Sequel.function(:pg_stat_reset)).first

            query_result = database.instance_eval(&query)
            options[:iterations].to_i.times do
              database.run(query_result.sql)
            end

            stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

            if stats[:temp_files] == 0 && stats[:temp_bytes] == 0
              return { name => value }
            end
          end
        end

        # TODO: Add a warning message or something.
        return { name => nil }
      end

      def to_markdown(results)
        current_work_mem = Tobias::WorkMem.from_sql(database.fetch("SHOW work_mem").first[:work_mem])

        <<~MARKDOWN
          ## #{description}

          | Query | Required work_mem |
          |-------|-------------------|
          #{results.map { |name, work_mem| "| #{name} | #{work_mem.to_sql} |" }.join("\n")}

          Your application will need to run with at least #{results.values.max.to_sql} of work_mem.

          I see that your current work_mem setting is #{current_work_mem.to_sql}.

          To apply my recommendations, run the following SQL:

          ```sql
          ALTER SYSTEM SET work_mem = '#{results.values.max.to_sql}';
          SELECT pg_reload_conf();
          ```
        MARKDOWN
      end
    end
  end
end
