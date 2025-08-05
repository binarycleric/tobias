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

      def run_each(name, query)
        database.run("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

        times = Concurrent::Array.new

        work_mems.each do |value|
          database.transaction do
            database.run("SET LOCAL work_mem = '#{value.to_sql}'")
            database.select(Sequel.function(:pg_stat_reset)).first

            query_result = database.instance_eval(&query)
            options[:iterations].to_i.times do
              times << Benchmark.realtime do
                database.run(query_result.sql)
              end
            end

            stats = database[:pg_stat_database].where(datname: Sequel.function(:current_database)).first

            if stats[:temp_files] == 0 && stats[:temp_bytes] == 0
              return Result.new(name: name, value: value, times: times)
            end
          end
        end
      end

      def to_markdown(results)
        if results.empty?
          return <<~MARKDOWN
            ## #{description}

            I couldn't figure out the required `work_mem` setting for your query.

            Please open an issue at https://github.com/binarycleric/tobias/issues
            and include your query script and copy of your database schema.
          MARKDOWN
        end

        current_work_mem = Tobias::WorkMem.from_sql(database.fetch("SHOW work_mem").first[:work_mem])

        table = TTY::Table.new(header: ["Query", "Required work_mem", "p99 Time", "Average"])
        results.each do |result|
          table << [
            result.name,
            result.value.to_sql,
            result.p99_time.round(2),
            result.average_time.round(2)
          ]
        end

        <<~MARKDOWN
          ## #{description}

          #{table.render_with(MarkdownTableBorder)}

          I see that your current `work_mem` setting is `#{current_work_mem.to_sql}`.

          Your application will need to run with at least `#{results.max(&:value).value.to_sql}` of `work_mem`.

          To apply my recommendations, run the following SQL:

          ```sql
          ALTER SYSTEM SET work_mem = '#{results.max(&:value).value.to_sql}';
          SELECT pg_reload_conf();
          ```
        MARKDOWN
      end
    end
  end
end
