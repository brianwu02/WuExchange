defmodule WuExchangeBackend.OrderScribe do
  @doc """
  TODO: store these orders somewhere other than just here :)
  """
  use GenServer

  alias WuExchangeBackend.Order

  def start_link() do
    orders = []
    GenServer.start_link(__MODULE__, orders, [])
  end

  def init(orders) do
    {:ok, orders}
  end

  def record_order(pid, %Order{} = order) do
    GenServer.cast(pid, {:record_order, order})
  end

  @doc """
  asyncronously record an order
  """
  def handle_cast({:record_order, %Order{} = order}, orders) do
    {:noreply, [order | orders]}
  end


end
