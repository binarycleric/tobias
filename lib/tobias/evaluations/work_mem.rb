# frozen_string_literal: true

module Tobias
  module Evaluations
    class WorkMem < Base
      def work_mems
        @work_mems ||= Tobias::WorkMem.valid_for(database)
      end

      def current_work_mem
        @current_work_mem ||= Tobias::WorkMem.from_sql(database.fetch("SHOW work_mem").first[:work_mem])
      end

      def description
        "Optimal work_mem settings"
      end

      def run_each(name, query)
        database.run("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

        work_mems.each do |value|
          database.transaction do
            database.run("SET LOCAL work_mem = '#{value.to_sql}'")
            database.select(Sequel.function(:pg_stat_reset)).first
            container.run_query(query)

            stats = database[:pg_stat_database].
              where(datname: Sequel.function(:current_database)).
              first

            if stats[:temp_files] == 0 && stats[:temp_bytes] == 0
              return Result.new(name: name, value: value)
            end
          end
        end

        # Fallback to the highest work_mem setting if no results are found.
        Result.new(name: name, value: work_mems.last)
      end

      def to_markdown(results)
        <<~MARKDOWN
          ## #{description}

          #{render_table(headers: ["Query", "Required work_mem"], body: results.map { |r| [r.name, r.value.to_sql] })}

          I see that your current `work_mem` setting is `#{current_work_mem.to_sql}`.

          Your application will need to run with at least `#{results.max.value.to_sql}` of `work_mem`.

          To apply my recommendations, run the following SQL:

          ```sql
          ALTER SYSTEM SET work_mem = '#{results.max.value.to_sql}';
          SELECT pg_reload_conf();
          ```
        MARKDOWN
      end
    end
  end
end
