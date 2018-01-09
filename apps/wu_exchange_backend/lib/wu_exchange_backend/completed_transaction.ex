defmodule WuExchangeBackend.CompletedTransaction do
  @moduledoc """
  represents a completed transcation between two orders
  """
  @enforce_keys [
    :transaction_id,
    :buy_order,
    :sell_order,
    :acknowledged_at,
  ]

  defstruct [
    transaction_id: 0,
    buy_order: Order,
    sell_order: Order,
    acknowledged_at: nil,
    type: nil
  ]

  # TODO: some functions here to generate default struct?

end
