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
    column :title, :text
    column :text, :text
    column :embedding, "vector(#{dimensions})"
  end

  class Item < Sequel::Model(:items)
    plugin :pgvector, :embedding
  end

  run_parallel(Dir.glob("/Users/jon/src/dbpedia-entities-openai-1M/data/*.parquet")) do |file|
    Parquet.each_row(file) do |row|
      Item.create(
        title: row["title"],
        text: row["text"],
        embedding: row["openai"]
      )
    end
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
