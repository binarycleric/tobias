# frozen_string_literal: true

option(:total_rows, 1_000_000)

setup do
  db.create_table? :workmem_stress do
    primary_key :id
    column :name, String
    column :value, Integer
    column :payload, String
    column :created_at, :timestamp, default: Sequel::CURRENT_TIMESTAMP
  end

  run_parallel do
    (options.total_rows / Etc.nprocessors / 1000).times do
      db.from(:workmem_stress).multi_insert(1000.times.map do
        {
          name: "name_#{Random.rand(1..1_000_000)}",
          value: Random.rand(1..1_000_000),
          payload: SecureRandom.hex(128)
        }
      end)
    end
  end

  db.add_index :workmem_stress, :name
end

teardown do
  db.drop_table(:workmem_stress)
end

query(:large_sort) do
  db.
    from(:workmem_stress).
    select(:id, :name, :value, :payload).
    order(Sequel.desc(:payload)).
    limit(10_000)
end

query(:large_sort_created_at) do
  db.
    from(:workmem_stress).
    select(:id, :name, :value, :payload).
    order(Sequel.desc(:created_at)).
    limit(10_000)
end

query(:hash_aggregation) do
  db.
    from(:workmem_stress).
    select(:name, Sequel.function(:avg, :value)).
    select { count("*") }.
    group(:name).
    limit(10_000)
end

query(:self_join) do
  db.
    from(Sequel.as(:workmem_stress, :a)).
    join(Sequel.as(:workmem_stress, :b), id: :id).
    where { Sequel[:a][:id] < 1000 }.
    where { Sequel[:b][:id] < 1000 }.
    select(
      Sequel[:a][:id].as(:a_id),
      Sequel[:b][:id].as(:b_id),
      Sequel.as(Sequel[:a][:value] + Sequel[:b][:value], :total_value)
    ).
    group(Sequel[:a][:id], Sequel[:b][:id]).
    limit(10_000)
end

query(:window_function) do
  db.from(:workmem_stress)
    .select(:id, :name, :value, :payload)
    .select{ Sequel.function(:row_number).over(order: Sequel.asc(:value)).as(:rn) }
    .order(Sequel.asc(:value))
    .limit(100_000)
end

query(:index_scan) do
  db.
    from(:workmem_stress).select(:id, :name, :value).
    where{ Sequel[:name] =~ 'name_%' }.
    order(Sequel.asc(:value)).
    limit(50_000)
end