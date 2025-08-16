# frozen_string_literal: true

option(:total_vectors, 5_000_000)
option(:vector_dimension, 1_536)

helpers do
  def random_vector(size: options.vector_dimension)
    Array.new(size) { rand(-1.0..1.0) }
  end
end

setup do
  run("CREATE EXTENSION IF NOT EXISTS vector")

  dimensions = options.vector_dimension
  create_table? :items do
    primary_key :id
    column :embedding, "vector(#{dimensions})"
  end
end

load_data do
  loop do
    break if from(:items).count >= options.total_vectors

    from(:items).multi_insert(1_000.times.map do
      {
        embedding: ::Pgvector.encode(random_vector)
      }
    end)
  end
end

teardown do
  drop_table(:items)
  run("DROP EXTENSION IF EXISTS vector")
end

query(:euclidean_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "euclidean"
    ).
    limit(10_000)
end

query(:cosine_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "cosine"
    ).
    limit(10_000)
end

query(:inner_product_nearest_neighbors) do
  from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "inner_product"
    ).
    limit(10_000)
end
