defmodule WuExchangeBackend.TransactionScribeTest do
  use ExUnit.Case, async: true
  doctest WuExchange

  setup do
    {:ok, server_pid} = TransactionScribe.start_link()
    {:ok, server: server_pid}
  end

  test "push_transaction/1 works", %{server: pid} do
    buy_order = %{trader_id: 1, order_id: 1, side: 0, price_in_cents: 500, quantity: 5}
    sell_order = %{trader_id: 2, order_id: 2, side: 1, price_in_cents: 500, quantity: 5}
    transaction = %CompletedTransaction{
      transaction_id: 1,
      buy_order: buy_order,
      sell_order: sell_order,
      acknowledged_at: :os.system_time(:micro_seconds),
    }
    assert :ok = TransactionScribe.push_transaction(pid, transaction)
  end

  test "handle_cast push_transaction correctly adds a transaction to the list of transactions" do
    buy_order = %{trader_id: 1, order_id: 1, side: 0, price_in_cents: 500, quantity: 5}
    sell_order = %{trader_id: 2, order_id: 2, side: 1, price_in_cents: 500, quantity: 5}
    transaction = %CompletedTransaction{
      transaction_id: 1,
      buy_order: buy_order,
      sell_order: sell_order,
      acknowledged_at: :os.system_time(:micro_seconds),
    }
    {:noreply, new_state} = TransactionScribe.handle_cast({:push, transaction}, [])
    assert length(new_state) == 1
  end

end
