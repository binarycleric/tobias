# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tobias::Container do
  let(:database) { instance_double("Database") }

  describe "#initialize" do
    it "stores the provided code" do
      code = "query(:test) { puts 'hello' }"
      container = described_class.new(code, database)

      expect(container.instance_variable_get(:@code)).to eq(code)
    end

    it "initializes empty queries hash" do
      container = described_class.new("", database)

      expect(container.queries).to eq({})
    end

    it "evaluates the provided code immediately" do
      code = <<~RUBY
        query(:simple_query) do
          from(:users).select(:id, :name)
        end
      RUBY

      container = described_class.new(code, database)

      expect(container.queries).to have_key(:simple_query)
      expect(container.queries[:simple_query]).to be_a(Proc)
    end

    it "handles empty code without error" do
      expect { described_class.new("", database) }.not_to raise_error
    end

    it "raises error for invalid Ruby syntax" do
      invalid_code = "query(:broken { syntax error"

      expect { described_class.new(invalid_code, database) }.to raise_error(SyntaxError)
    end
  end

  describe "#query" do
    let(:container) { described_class.new("", database) }

    it "stores a query with the given name and block" do
      test_block = proc { "test query" }

      container.query(:test_query, &test_block)

      expect(container.queries[:test_query]).to eq(test_block)
    end

    it "allows multiple queries to be stored" do
      container.query(:first_query) { "first" }
      container.query(:second_query) { "second" }

      expect(container.queries).to have_key(:first_query)
      expect(container.queries).to have_key(:second_query)
      expect(container.queries.size).to eq(2)
    end

    it "overwrites existing queries with the same name" do
      container.query(:duplicate) { "original" }
      container.query(:duplicate) { "updated" }

      expect(container.queries[:duplicate].call).to eq("updated")
    end

    it "accepts string keys" do
      container.query("string_key") { "test" }

      expect(container.queries["string_key"]).to be_a(Proc)
    end
  end

  describe "#queries" do
    it "returns an empty hash when no queries are defined" do
      container = described_class.new("", database)

      expect(container.queries).to eq({})
    end

    it "returns all stored queries" do
      code = <<~RUBY
        query(:users) { from(:users) }
        query(:orders) { from(:orders) }
      RUBY

      container = described_class.new(code, database)

      expect(container.queries.keys).to contain_exactly(:users, :orders)
    end

    it "returns queries that can be called" do
      code = <<~RUBY
        query(:test) { "executable" }
      RUBY

      container = described_class.new(code, database)

      expect(container.queries[:test].call).to eq("executable")
    end
  end

  describe "integration with Sequel-style queries" do
    it "stores complex query blocks" do
      code = <<~RUBY
        query(:complex_query) do
          from(:orders).
            join(:order_items, order_id: :id).
            join(:products, id: :product_id).
            where(created_at: Date.today.beginning_of_month..Date.today).
            group(:category).
            select(
              :category,
              Sequel.function(:sum, :quantity).as(:total_quantity),
              Sequel.function(:avg, :price).as(:avg_price)
            ).
            order(:total_quantity)
        end
      RUBY

      container = described_class.new(code, database)
      query_block = container.queries[:complex_query]

      expect(query_block).to be_a(Proc)
      # We can't test the Sequel code without a database context,
      # but we can verify the block is stored properly
      expect(query_block.arity).to eq(0) # Should be a no-argument block
    end

    it "handles queries with local variables" do
      code = <<~RUBY
        query(:with_variables) do
          warehouse_id = from(:warehouse).where(w_id: 1).first[:w_id]
          threshold = 500

          from(:stock).where(s_w_id: warehouse_id, s_quantity: threshold)
        end
      RUBY

      container = described_class.new(code, database)
      query_block = container.queries[:with_variables]

      expect(query_block).to be_a(Proc)
    end
  end

  describe "error handling" do
    it "propagates runtime errors from query blocks" do
      code = <<~RUBY
        query(:error_query) do
          raise StandardError, "Query execution failed"
        end
      RUBY

      container = described_class.new(code, database)
      query_block = container.queries[:error_query]

      expect { query_block.call }.to raise_error(StandardError, "Query execution failed")
    end

    it "handles code that defines methods" do
      code = <<~RUBY
        def helper_method
          "helper"
        end

        query(:with_helper) do
          helper_method + " query"
        end
      RUBY

      container = described_class.new(code, database)

      expect(container.queries[:with_helper].call).to eq("helper query")
    end

    it "isolates code execution in its own binding" do
      # Define a variable in this test scope
      test_variable = "should not be accessible"

      code = <<~RUBY
        query(:isolated) do
          # This should not have access to test_variable
          defined?(test_variable) ? test_variable : "isolated"
        end
      RUBY

      container = described_class.new(code, database)

      expect(container.queries[:isolated].call).to eq("isolated")
    end
  end

  describe "real-world usage patterns" do
    it "handles the TPC-C example structure" do
      code = <<~RUBY
        query(:stock_by_warehouse_and_district) do
          warehouse_id = from(:warehouse).where(w_id: 1).first[:w_id]
          district_id = from(:district).where(d_w_id: warehouse_id).first[:d_id]
          threshold = 500

          from(:stock).
            join(:order_line, ol_w_id: :s_w_id, ol_i_id: :s_i_id).
            where(ol_w_id: warehouse_id, ol_d_id: district_id).
            where(Sequel.lit("s_quantity < ?", threshold)).
            select(Sequel.function(:count, Sequel.function(:distinct, :s_i_id)).as(:count))
        end

        query(:order_lines_by_warehouse) do
          warehouse_id = from(:warehouse).where(w_id: 1).first[:w_id]
          threshold = 20

          from(:stock).
            join(:order_line, ol_w_id: :s_w_id, ol_i_id: :s_i_id).
            where(ol_w_id: warehouse_id).
            where(Sequel.lit("s_quantity < ?", threshold)).
            select(Sequel.function(:count, Sequel.function(:distinct, :s_i_id)).as(:count))
        end
      RUBY

      container = described_class.new(code, database)

      expect(container.queries.keys).to contain_exactly(
        :stock_by_warehouse_and_district,
        :order_lines_by_warehouse
      )

      container.queries.each_value do |query_block|
        expect(query_block).to be_a(Proc)
      end
    end

    it "maintains query order when iterated" do
      code = <<~RUBY
        query(:first) { "1" }
        query(:second) { "2" }
        query(:third) { "3" }
      RUBY

      container = described_class.new(code, database)

      # Ruby hash preserves insertion order in Ruby 2.7+
      expect(container.queries.keys).to eq([:first, :second, :third])
    end
  end
end