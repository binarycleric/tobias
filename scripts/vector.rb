# frozen_string_literal: true

require "open3"
require "tmpdir"

helpers do
  def random_vector(size: 1_536)
    Array.new(size) { rand(-1.0..1.0) }
  end

  def download_from_hugging_face(repo)
    local_dir = Dir.mktmpdir("hf-#{repo}-")
    stdout, status = Open3.capture2(
      "which", "hf"
    )

    unless status.success?
      raise "Failed to find huggingface CLI: #{stdout}"
    end

    stdout, status = Open3.capture2(
      "hf", "download", repo, "--repo-type=dataset", "--local-dir", local_dir
    )

    unless status.success?
      raise "Failed to download #{repo}: #{stdout}"
    end

    local_dir
  end
end

setup do
  db.run("CREATE EXTENSION IF NOT EXISTS vector")

  db.create_table? :items do
    primary_key :id
    column :title, :text
    column :text, :text
    column :embedding, "vector(#{1_536})"
    column :created_at, :timestamp, default: Sequel::CURRENT_TIMESTAMP
  end

  local_dir = download_from_hugging_face("KShivendu/dbpedia-entities-openai-1M")
  run_parallel(Dir.glob("#{local_dir}/data/*.parquet")) do |file|
    Parquet.each_row(file, columns: ["title", "text", "openai"]) do |row|
      db.from(:items).insert(
        title: row["title"],
        text: row["text"],
        embedding: "[#{row["openai"].join(",")}]"
      )
    end
  end

  db.run("SET maintenance_work_mem = '128MB';")
  db.run("CREATE INDEX IF NOT EXISTS items_embedding_idx ON items USING ivfflat (embedding) WITH (lists = 100)")
end

teardown do
  db.drop_table(:items)
  db.run("DROP EXTENSION IF EXISTS vector")
end

query(:euclidean_nearest_neighbors) do
  db.
    from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "euclidean"
    ).
    limit(10_000)
end

query(:cosine_nearest_neighbors) do
  db.
    from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "cosine"
    ).
    limit(10_000)
end

query(:inner_product_nearest_neighbors) do
  db.
    from(:items).
    nearest_neighbors(
      :embedding,
      random_vector,
      distance: "inner_product"
    ).
    limit(10_000)
end
