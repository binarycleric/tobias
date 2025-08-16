# frozen_string_literal: true

option(:total_rows, 10_000_000)

setup do
  create_table? :workmem_stress do
    primary_key :id
    column :name, String
    column :value, Integer
    column :payload, String
  end
end

load_data do
  loop do
    break if from(:workmem_stress).count >= options.total_rows

    100.times do
      from(:workmem_stress).multi_insert(1000.times.map do
        {
          name: "name_#{Random.rand(1..1000)}",
          value: Random.rand(1..10_000),
          payload: SecureRandom.hex(128)
        }
      end)
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
