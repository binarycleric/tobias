# Tobias

Tobias is your friendly PostgreSQL DBA who is obsessed with optimizing your database.

Named after a nerdy but friendly DBA who is obsessed with query performance, Tobias helps you find the optimal `work_mem` setting for your PostgreSQL queries. It runs your queries with various memory settings to determine the minimum `work_mem` needed to keep your queries entirely in memory without creating temporary files.

## Installation

```shell
$ gem install tobias
```

## How It Works

Tobias tests your queries against a range of `work_mem` settings (from 64kB to 8GB) and determines the minimum memory required to avoid temporary file spill-over. This helps you:

- Optimize query performance by keeping operations in memory
- Right-size your `work_mem` setting per query or workload
- Avoid over-allocating memory while preventing disk spill

## Usage

### Basic Usage

```shell
$ tobias profile path/to/your/script.rb --database-url <database-url>
```

### Options

- `--database-url`: PostgreSQL connection string (required)
- `--iterations`: Number of times to run each query for testing (default: 10)
- `--debug`: Enable debug logging (default: false)

### Creating Query Scripts

Create a Ruby script that defines your queries using the `query` method:

```ruby
# my_queries.rb

query(:complex_aggregation) do
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

query(:heavy_join) do
  from(:customers).
    join(:orders, customer_id: :id).
    join(:order_items, order_id: Sequel[:orders][:id]).
    where(Sequel[:customers][:created_at] > Date.today - 365).
    select(
      Sequel[:customers][:email],
      Sequel.function(:count, Sequel[:orders][:id]).as(:order_count),
      Sequel.function(:sum, Sequel[:order_items][:quantity]).as(:total_items)
    ).
    group(Sequel[:customers][:id], Sequel[:customers][:email])
end
```

Each `query` block should contain [Sequel ORM](https://sequel.jeremyevans.net/) code that builds and returns a dataset.

### Example Run

```shell
$ tobias profile scripts/tpcc.rb --database-url postgres://localhost/tpcc_test
```

### Output

#### @tobias is thinking...

#### @tobias has sent you a new message

I thought about your queries for 2.34 seconds and here is what I recommend:

| Query | Required work_mem |
|-------|-------------------|
| stock_by_warehouse_and_district | 4MB |
| order_lines_by_warehouse | 8MB |

Your application will need to run with at least 8MB of work_mem.

To apply my recommendations, run the following SQL:

```sql
SET work_mem = '8MB';
```

Regards,
~ Tobias

### Output Explanation

- Tobias shows a "thinking" phase while analyzing your queries
- Results are presented in a friendly, conversational format with timing information
- A table shows the minimum `work_mem` needed for each query to avoid temporary files
- The final recommendation uses the maximum `work_mem` needed across all queries
- This ensures all your queries will run efficiently in memory
- The output includes ready-to-use SQL for applying the recommendations

## Example Script

See `scripts/tpcc.rb` for a complete example that tests TPC-C benchmark queries.

## Requirements

- Ruby 3.3+
- PostgreSQL database with `pg_stat_database` access
- Your database user needs permissions to:
  - Execute `SET work_mem`
  - Read from `pg_stat_database`
  - Execute `pg_stat_reset()`
