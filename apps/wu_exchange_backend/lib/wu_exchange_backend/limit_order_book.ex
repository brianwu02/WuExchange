defmodule WuExchangeBackend.LimitOrderBook do
  @moduledoc """
  Struct to represent a Limit Order Book

  """
  defstruct name: "WUXC",
  global_order_id: 0,
  transaction_id: 0,
  price_points: %{},
  active_orders: %{count: 0},
  max_price_in_cents: 0,
  bid_max_in_cents: 0,
    ask_min_in_cents: 0, # needs to be set to max_price_in_cents + 1
  completed_transactions: %{}

end
