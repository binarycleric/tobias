# frozen_string_literal: true

setup do
  run(<<~SQL)
    CREATE TABLE IF NOT EXISTS workmem_stress (
      id SERIAL PRIMARY KEY,
      name TEXT,
      value INTEGER,
      payload TEXT
    )
  SQL

  transaction do |c|
    1_000_000.times do |i|
      name = "name_#{i % 1000}"
      value = rand(1..10_000)
      payload = SecureRandom.hex(128)

      from(:workmem_stress).insert(name: name, value: value, payload: payload)
    end
  end
end

teardown do
  drop_table(:workmem_stress)
end

query(:large_sort) do
  from(:workmem_stress)
    .select(:id, :name, :value, :payload)
    .order(Sequel.desc(:payload))
    .limit(10_000)
end

query(:hash_aggregation) do
  from(:workmem_stress)
    .select(:name, Sequel.function(:avg, :value))
    .select { count("*") }
    .group(:name)
    .limit(10_000)
end

query(:self_join) do
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
