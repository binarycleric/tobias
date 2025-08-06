# frozen_string_literal: true

query(:stock_by_warehouse_and_district) do
  warehouse_id = from(:warehouse).
    order(Sequel.lit("RANDOM()")).
    limit(1).
    first[:w_id]

  district_id = from(:district).
    where(d_w_id: warehouse_id).
    order(Sequel.lit("RANDOM()")).
    limit(1).
    first[:d_id]

  from(:stock).
    join(:order_line, ol_w_id: :s_w_id, ol_i_id: :s_i_id).
    where(ol_w_id: warehouse_id, ol_d_id: district_id).
    where(Sequel.lit("s_quantity < ?", rand(100..500))).
    order(:s_quantity).
    group(:s_i_id, :s_quantity).
    limit(2_000).
    select(Sequel.function(:count, Sequel.function(:distinct, :s_i_id)).as(:count))
end
