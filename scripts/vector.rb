# frozen_string_literal: true

TOTAL_VECTORS = 5_000_000
VECTOR_DIMENSION = 1536
STARTING_POINT = VECTOR_DIMENSION.times.map { Random.rand(-1.0..1.0) }

setup do
  run("CREATE EXTENSION IF NOT EXISTS vector")

  create_table? :items do
    primary_key :id
    column :embedding, "vector(#{VECTOR_DIMENSION})"
  end

  Etc.nprocessors.times do
    fork do
      disconnect

      loop do
        break if from(:items).count >= TOTAL_VECTORS

        50.times do
          from(:items).multi_insert(500.times.map do
            { embedding: ::Pgvector.encode(VECTOR_DIMENSION.times.map { Random.rand(-1.0..1.0) }) }
          end)
        end
      end
    end
  end

  disconnect
  Process.waitall
end

teardown do
  drop_table(:items)
  run("DROP EXTENSION IF EXISTS vector")
end

query(:euclidean_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      STARTING_POINT,
      distance: "euclidean"
    ).
    limit(10_000)
end

query(:cosine_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      STARTING_POINT,
      distance: "cosine"
    ).
    limit(10_000)
end

query(:inner_product_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      STARTING_POINT,
      distance: "inner_product"
    ).
    limit(10_000)
end
