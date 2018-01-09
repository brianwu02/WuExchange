defmodule WuExchangeBackend.Order do
  @moduledoc """
  An Order

  Side: 0=buy, 1=sell

  """
  defstruct order_id: nil,
    trader_id: nil,
    side: 0,
    quantity: nil,
    price_in_cents: nil,
    acknowledged_at: nil, # unix timestamp acknowledged by server
    modified_at: nil # for use when we modify the quantity of the order
end
