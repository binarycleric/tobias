# frozen_string_literal: true

TOTAL_VECTORS = 1_000_000
VECTOR_DIMENSION = 1536

setup do
  run("CREATE EXTENSION IF NOT EXISTS vector")
  run(<<~SQL)
    CREATE TABLE IF NOT EXISTS items (
      id bigserial PRIMARY KEY,
      embedding vector(1536)
    )
  SQL

  Etc.nprocessors.times do
    fork do
      disconnect

      loop do
        break if from(:items).count >= TOTAL_VECTORS

        from(:items).multi_insert(500.times.map do
          { embedding: ::Pgvector.encode(VECTOR_DIMENSION.times.map { rand(-1.0..1.0) }) }
        end)
      end
    end
  end

  disconnect
  Process.waitall
end

teardown do
  run("DROP TABLE IF EXISTS items")
  run("DROP EXTENSION IF EXISTS vector")
end

query(:euclidean_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      VECTOR_DIMENSION.times.map { rand(-1.0..1.0) },
      distance: "euclidean"
    ).
    limit(10_000)
end

query(:cosine_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      VECTOR_DIMENSION.times.map { rand(-1.0..1.0) },
      distance: "cosine"
    ).
    limit(10_000)
end

query(:jaccard_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      1536.times.map { rand(-1.0..1.0) },
      distance: "inner_product"
    ).
    limit(10_000)
end
