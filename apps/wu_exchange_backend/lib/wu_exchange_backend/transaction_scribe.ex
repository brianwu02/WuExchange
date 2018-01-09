defmodule WuExchangeBackend.TransactionScribe do

 @moduledoc """
  Writes all transactions somewhere. We don't know where, but somewhere!

  Runtime Characteristic:
  This GenServer receives transactions from the MatchingEngine asyncronously

  Public API:
  push_transaction(<PID>, %CompletedTransaction{}) - pushes a completed transcation
  and broadcasts event to respective clients

  Example:
  transaction = %CompletedTransaction{
    buy_order: %Order{side: 0, trader_id: 1, quantity: 25, price_in_cents: 2500},
    sell_oder: %Order{side: 1, trader_id: 2, quantity: 20, price_in_cents: 2500},
  }
  1. pushes transaction on to our list of transcations
  2. notifies Trader Process with trader_id: 1 and trader_id: 2

  """

  use GenServer

  alias WuExchangeBackend.CompletedTransaction

  def start_link(name \\ "WUXC") do
    transactions = []
    GenServer.start_link(__MODULE__, transactions, [])
  end

  def init([] = transactions) do
    {:ok, transactions}
  end

  def push_transaction(pid, %CompletedTransaction{} = transaction) do
    GenServer.cast(pid, {:push, transaction})
  end

  @doc """
  pushes the completed transaction on to our stack
  """
  def handle_cast({:push, %CompletedTransaction{} = transaction}, state) do
    {:noreply, [transaction | state]}
  end

  defp broadcast_transaction(%CompletedTransaction{} = transaction) do
  end

end
