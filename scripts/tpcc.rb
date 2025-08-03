# frozen_string_literal: true

query(:stock_by_warehouse_and_district) do
  warehouse_id = database.from(:warehouse).where(w_id: 1).first[:w_id]
  district_id = database.from(:district).where(d_w_id: warehouse_id).first[:d_id]
  threshold = 500

  database.from(:stock).
    join(:order_line, ol_w_id: :s_w_id, ol_i_id: :s_i_id).
    where(ol_w_id: warehouse_id, ol_d_id: district_id).
    where(Sequel.lit("s_quantity < ?", threshold)).
    select(Sequel.function(:count, Sequel.function(:distinct, :s_i_id)).as(:count))
end
