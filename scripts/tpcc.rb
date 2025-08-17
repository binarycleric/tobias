# frozen_string_literal: true

query(:stock_by_warehouse_and_district) do
  warehouse_id = db.from(:warehouse).
    order(Sequel.lit("RANDOM()")).
    limit(1).
    first[:w_id]

  district_id = from(:district).
    where(d_w_id: warehouse_id).
    order(Sequel.lit("RANDOM()")).
    limit(1).
    first[:d_id]

  db.from(:stock).
    join(:order_line, ol_w_id: :s_w_id, ol_i_id: :s_i_id).
    where(ol_w_id: warehouse_id, ol_d_id: district_id).
    where(Sequel.lit("s_quantity < ?", rand(100..500))).
    order(:s_quantity).
    group(:s_i_id, :s_quantity).
    limit(100).
    select(Sequel.function(:count, Sequel.function(:distinct, :s_i_id)).as(:count))
end

query(:most_active_districts) do
  db.
    from(:district).
    join(:order_line, [[:ol_d_id, :d_id], [:ol_w_id, :d_w_id]]).
    group(:d_w_id, :d_id, :d_name).
    select(
    :d_w_id,
    :d_id,
    :d_name,
    Sequel.function(:count, :ol_number).as(:order_line_count)
  ).
  order(Sequel.desc(:order_line_count)).
  limit(100)
end

# Complex Analytics Query: Customer Purchase Behavior Analysis with District Rankings
query(:customer_purchase_behavior_analysis, <<~SQL)
  WITH customer_metrics AS (
    SELECT
      -- Customer information
      c.c_w_id AS warehouse_id,
      c.c_d_id AS district_id,
      c.c_id AS customer_id,
      c.c_first AS customer_first_name,
      c.c_last AS customer_last_name,
      c.c_balance AS customer_balance,
      c.c_ytd_payment AS customer_ytd_payment,
      c.c_payment_cnt AS customer_payment_count,
      c.c_delivery_cnt AS customer_delivery_count,
      c.c_since AS customer_since,

      -- District and warehouse info
      d.d_name AS district_name,
      w.w_name AS warehouse_name,
      w.w_tax AS warehouse_tax_rate,
      d.d_tax AS district_tax_rate,

      -- Aggregated order metrics
      COUNT(DISTINCT o.o_id) AS total_orders,
      COUNT(ol.ol_number) AS total_order_lines,
      SUM(ol.ol_amount) AS total_order_value,
      AVG(ol.ol_amount) AS avg_order_line_value,
      SUM(ol.ol_quantity) AS total_quantity_ordered,
      COUNT(DISTINCT ol.ol_i_id) AS distinct_items_ordered,

      -- Payment history aggregations
      COUNT(h.h_id) AS payment_history_count,
      COALESCE(SUM(h.h_amount), 0) AS total_payment_amount,

      -- Stock level insights
      AVG(s.s_quantity) AS avg_stock_quantity,
      MIN(s.s_quantity) AS min_stock_quantity,
      MAX(s.s_quantity) AS max_stock_quantity,

      -- Item price analysis
      AVG(i.i_price) AS avg_item_price,
      MAX(i.i_price) AS max_item_price,

      -- Order timing analysis
      MIN(o.o_entry_d) AS first_order_date,
      MAX(o.o_entry_d) AS last_order_date,
      AVG(EXTRACT(EPOCH FROM (o.o_entry_d - c.c_since))/86400) AS avg_days_since_customer_created,

      -- Additional metrics for window function stress testing
      STDDEV(ol.ol_amount) AS order_line_amount_stddev,
      VARIANCE(ol.ol_quantity) AS order_quantity_variance

    FROM customer c
      INNER JOIN district d ON d.d_w_id = c.c_w_id AND d.d_id = c.c_d_id
      INNER JOIN warehouse w ON w.w_id = c.c_w_id
      INNER JOIN orders o ON o.o_w_id = c.c_w_id AND o.o_d_id = c.c_d_id AND o.o_c_id = c.c_id
      INNER JOIN order_line ol ON ol.ol_w_id = o.o_w_id AND ol.ol_d_id = o.o_d_id AND ol.ol_o_id = o.o_id
      INNER JOIN item i ON i.i_id = ol.ol_i_id
      INNER JOIN stock s ON s.s_w_id = ol.ol_w_id AND s.s_i_id = ol.ol_i_id
      LEFT JOIN history h ON h.h_c_w_id = c.c_w_id AND h.h_c_d_id = c.c_d_id AND h.h_c_id = c.c_id

    WHERE
      o.o_entry_d >= CURRENT_DATE - INTERVAL '1 year'
      AND ol.ol_amount > 0
      AND c.c_balance > -1000  -- Active customers only
      AND s.s_quantity IS NOT NULL

    GROUP BY
      c.c_w_id, c.c_d_id, c.c_id, c.c_first, c.c_last, c.c_balance,
      c.c_ytd_payment, c.c_payment_cnt, c.c_delivery_cnt, c.c_since,
      d.d_name, w.w_name, w.w_tax, d.d_tax

    HAVING
      COUNT(DISTINCT o.o_id) > 5
      AND SUM(ol.ol_amount) > 100.0
  ),

  -- Additional CTE for percentile calculations (stresses memory with multiple sorts)
  customer_percentiles AS (
    SELECT
      warehouse_id,
      district_id,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_order_line_value) AS district_median_order_line_value,
      PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_orders) AS district_q1_total_orders,
      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_orders) AS district_q3_total_orders,
      PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_order_value) AS district_p95_order_value
    FROM customer_metrics
    GROUP BY warehouse_id, district_id
  ),

  warehouse_percentiles AS (
    SELECT
      warehouse_id,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_order_line_value) AS warehouse_median_order_line_value,
      PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_order_value) AS warehouse_p90_order_value,
      PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY customer_balance) AS warehouse_p10_balance
    FROM customer_metrics
    GROUP BY warehouse_id
  )

  SELECT
    -- Base customer data
    cm.warehouse_id,
    cm.district_id,
    cm.customer_id,
    cm.customer_first_name,
    cm.customer_last_name,
    cm.customer_balance,
    cm.customer_ytd_payment,
    cm.customer_payment_count,
    cm.customer_delivery_count,
    cm.district_name,
    cm.warehouse_name,
    cm.warehouse_tax_rate,
    cm.district_tax_rate,

    -- Aggregated metrics
    cm.total_orders,
    cm.total_order_lines,
    cm.total_order_value,
    cm.avg_order_line_value,
    cm.total_quantity_ordered,
    cm.distinct_items_ordered,
    cm.payment_history_count,
    cm.total_payment_amount,
    cm.avg_stock_quantity,
    cm.min_stock_quantity,
    cm.max_stock_quantity,
    cm.avg_item_price,
    cm.max_item_price,
    cm.first_order_date,
    cm.last_order_date,
    cm.avg_days_since_customer_created,
    cm.order_line_amount_stddev,
    cm.order_quantity_variance,

    -- Percentile data from CTEs
    cp.district_median_order_line_value,
    cp.district_q1_total_orders,
    cp.district_q3_total_orders,
    cp.district_p95_order_value,
    wp.warehouse_median_order_line_value,
    wp.warehouse_p90_order_value,
    wp.warehouse_p10_balance,

    -- Complex window functions for ranking and analytics (these stress work_mem heavily)
    ROW_NUMBER() OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_order_value DESC
    ) AS customer_rank_by_value_in_district,

    DENSE_RANK() OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.total_orders DESC
    ) AS customer_rank_by_orders_in_warehouse,

    PERCENT_RANK() OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.customer_balance
    ) AS customer_balance_percentile,

    CUME_DIST() OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.total_order_value
    ) AS customer_order_value_cumulative_distribution,

    NTILE(10) OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.total_order_value
    ) AS customer_decile_by_value,

    NTILE(5) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_orders
    ) AS customer_quintile_by_orders_in_district,

    -- Running totals and moving averages (very memory intensive)
    SUM(cm.total_order_value) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.customer_id
      ROWS UNBOUNDED PRECEDING
    ) AS running_total_order_value,

    AVG(cm.total_order_value) OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.customer_id
      ROWS 100 PRECEDING  -- 100-row moving average
    ) AS moving_avg_order_value_100,

    SUM(cm.total_orders) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.customer_since
      ROWS BETWEEN 50 PRECEDING AND 50 FOLLOWING  -- 101-row centered window
    ) AS centered_sum_orders_101,

    -- Lead/Lag functions for trend analysis
    LAG(cm.customer_balance, 1) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.customer_since
    ) AS previous_customer_balance,

    LAG(cm.total_order_value, 2) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_order_value
    ) AS second_previous_order_value,

    LEAD(cm.total_order_value, 1) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_order_value
    ) AS next_customer_order_value,

    LEAD(cm.customer_balance, 3) OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.customer_since
    ) AS third_next_customer_balance,

    -- More complex window functions
    FIRST_VALUE(cm.total_order_value) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_order_value DESC
      ROWS UNBOUNDED PRECEDING
    ) AS highest_order_value_in_district,

    LAST_VALUE(cm.customer_balance) OVER (
      PARTITION BY cm.warehouse_id
      ORDER BY cm.customer_since
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS most_recent_customer_balance_in_warehouse,

    NTH_VALUE(cm.total_order_value, 3) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.total_order_value DESC
      ROWS UNBOUNDED PRECEDING
    ) AS third_highest_order_value_in_district,

    -- Cross-partition comparisons (forces large sorts across partitions)
    AVG(cm.total_order_value) OVER () AS global_avg_order_value,

    MAX(cm.total_order_value) OVER () AS global_max_order_value,

    cm.total_order_value / NULLIF(AVG(cm.total_order_value) OVER (
      PARTITION BY cm.warehouse_id
    ), 0) AS order_value_ratio_to_warehouse_avg,

    -- Complex conditional aggregations within windows
    SUM(CASE WHEN cm.total_orders > 10 THEN cm.total_order_value ELSE 0 END) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
    ) AS high_activity_customer_value_in_district,

    COUNT(CASE WHEN cm.customer_balance > 0 THEN 1 END) OVER (
      PARTITION BY cm.warehouse_id
    ) AS positive_balance_customers_in_warehouse,

    AVG(CASE WHEN cm.total_orders > 5 THEN cm.avg_order_line_value END) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
      ORDER BY cm.customer_since
      ROWS 25 PRECEDING
    ) AS conditional_moving_avg_order_line_value,

    -- Statistical functions that require sorting and memory
    STDDEV(cm.total_order_value) OVER (
      PARTITION BY cm.warehouse_id
    ) AS warehouse_order_value_stddev,

    VARIANCE(cm.customer_balance) OVER (
      PARTITION BY cm.warehouse_id, cm.district_id
    ) AS district_balance_variance

  FROM customer_metrics cm
    LEFT JOIN customer_percentiles cp ON cp.warehouse_id = cm.warehouse_id
      AND cp.district_id = cm.district_id
    LEFT JOIN warehouse_percentiles wp ON wp.warehouse_id = cm.warehouse_id

  ORDER BY
    cm.total_order_value DESC,
    cm.total_orders DESC,
    cm.warehouse_id,
    cm.district_id,
    customer_rank_by_value_in_district

  LIMIT 100;
SQL