defmodule WuExchangeBackend.MatchingEngine do
  @moduledoc """
  """

  use GenServer

  alias WuExchangeBackend.{
    Order,
    LimitOrderBook,
    CompletedTransaction,
  }


  def start_link(name \\ "WUXC", max_price_in_cents \\ 100_000) do
    price_points =
      Enum.reduce(0..max_price_in_cents, %{}, fn(x, acc) -> Map.put(acc, x, :queue.new()) end)
    order_book = %LimitOrderBook{
      name: name,
      price_points: Enum.reduce(0..max_price_in_cents, %{}, fn(x, acc) ->
        # insert a queue at each price point
        Map.put(acc, x, :queue.new())
      end),
      active_orders: %{
        count: 0,
      }, # map of active orders??
      transaction_id: 0, # global transaction counter
      global_order_id: 0, # order id counter
      max_price_in_cents: max_price_in_cents,
      bid_max_in_cents: 0, # tracks maximum bid
      ask_min_in_cents: max_price_in_cents + 1, # tracks maximum minimum ask
    }

    # initialize data structure that will keep track of Buy Limit Orders
    GenServer.start_link(__MODULE__, order_book, [])
  end

  # Client Interface

  def init(%{} = order_book) do
    {:ok, order_book}
  end

  @doc """
  """
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc """
  return count of active orders
  """
  def active_order_count(pid), do: GenServer.call(pid, {:active_order_count})

  @doc """
  Returns a List of Orders at a specific price point in cents
  """
  def orders_at_price_point(pid, price_point) when is_number(price_point) do
    GenServer.call(pid, {:orders_at_price_point, price_point})
  end

  @doc """
  create a Sell Limit Order
  """
  def sell_limit_order(pid: pid, trader_id: _t_id, price_in_cents: price_in_cents, quantity: quantity
  ) when price_in_cents <= 0 or quantity <= 0 do
    {:ok, :rejected}
  end
  def sell_limit_order(pid: pid, trader_id: t_id, price_in_cents: price_in_cents, quantity: q) do
    order = %Order{trader_id: t_id, side: 1, price_in_cents: price_in_cents, quantity: q}
    GenServer.call(pid, {:limit_order, order})
  end

  @doc """
  Create a Buy Limit Order
  """
  def buy_limit_order(pid: pid, trader_id: t_id, price_in_cents: price_in_cents, quantity: q) do
    order = %Order{trader_id: t_id, side: 0, price_in_cents: price_in_cents, quantity: q}
    GenServer.call(pid, {:limit_order, order})
  end

  def cancel_order(pid, order_id) when is_integer(order_id) and is_pid(pid) do
    GenServer.call(pid, {:cancel_order, order_id})
  end

  # Server Interface

  @doc """
  Cancel an Order
  """
  def handle_call({:cancel_order, order_id}, _from, lob) do
    case cancel_order(lob, order_id) do
      {:ok, lob, order} ->
        {:reply, {:ok, order}, lob}
      {:fail, lob} ->
        {:reply, {:ok, :fail}, lob}
    end
  end

  def handle_call({:active_order_count}, _from, %LimitOrderBook{active_orders: %{count: count}} = lob) do
    {:reply, {:ok, count}, lob}
  end

  def handle_call(:status, _from, %LimitOrderBook{} = limit_order_book) do
    {:reply, {:ok, limit_order_book}, limit_order_book}
  end

  @doc """
  returns all orders at a specific price_point
  """
  def handle_call({:orders_at_price_point, price_point}, _from, %LimitOrderBook{price_points: price_points} = limit_order_book) do
    {:ok, price_points_queue} = Map.fetch(price_points, price_point)
    {:reply, {:ok, :queue.to_list(price_points_queue)}, limit_order_book}
  end

  # match against order_price_in_cents > max_price_in_cents and :reject the or
  def handle_call({:limit_order, %Order{price_in_cents: order_price_in_cents}},
                  _from,
                  %{max_price_in_cents: max_price_in_cents} = order_book
  ) when order_price_in_cents > max_price_in_cents do
    {:reply, {:reject, %{reason: "order_price_in_cents > max_price_in_cents"}}, order_book}
  end

  def handle_call({:limit_order, %Order{} = order}, _from, %LimitOrderBook{} = lob) do
    # acknowledge our order
    {%LimitOrderBook{} = lob, %Order{} = order} = acknowledge_order(lob, order)
    # run price-time matching algorithm
    {%LimitOrderBook{} = lob, %Order{} = order, executed_orders} = price_time_match(order, lob, [])
    {:reply, {:ok, order}, lob}
  end

  @doc """
  cancel an order.
  Pre-Requisite:
    1. order_id must exist
    2. order belongs to same trader

  we know we can cancel an order if it's in the active_orders
  """
  def cancel_order(%LimitOrderBook{active_orders: active_orders, price_points: price_points} = lob,
                   order_id
  ) when is_number(order_id) do
    # try and fetch the order from active_orders
    case Map.fetch(active_orders, order_id) do
      # if we find it, perform the delete action
      {:ok, %Order{order_id: order_id_to_delete, price_in_cents: price_in_cents} = order_to_delete} ->
        # get remove from active orders
        lob = remove_active_order(lob, order_to_delete)
        # now get queue for the specific price point
        price_points_queue = Map.fetch!(price_points, price_in_cents)
        # now remove it from the price point, this operation is expensive :(
        price_points_queue = :queue.filter(fn(%Order{order_id: order_id}) ->
          order_id != order_id_to_delete
        end, price_points_queue)
        # put price points queue back in our state
        price_points = put_in(price_points, [price_in_cents], price_points_queue)
        lob = %{lob | price_points: price_points}
        {:ok, lob, order_to_delete}
      :error ->
        {:fail, lob}
    end
  end

@doc """
  FIFO Price-Time Matching Algorithm for Buy-Side Order
  """
  def price_time_match(%Order{side: 0, price_in_cents: order_price_in_cents, quantity: order_quantity} = order,
                       %LimitOrderBook{price_points: price_points, ask_min_in_cents: ask_min_in_cents} = lob,
                       completed_transactions \\ []
  ) when order_price_in_cents >= ask_min_in_cents do
    price_points_queue = Map.fetch!(price_points, ask_min_in_cents)
    # peek first item in queue and perform logic based on it
    case :queue.peek(price_points_queue) do
      :empty ->
        # when it's empty, we continue to decrement
        price_time_match(order, increment_ask_min_in_cents(lob), completed_transactions)
      {:value, %Order{quantity: matched_quantity} = matched_order} ->
        cond do
          matched_quantity == order_quantity ->
            # pop the order off the queue
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            lob = remove_active_order(lob, popped_order)
            # set the price points map. this can definitely be refactored
            price_points = put_in(price_points, [ask_min_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            # execute the buy order here
            {lob, order, completed_transaction} = execute_buy_order(lob, order, popped_order)
            {lob, order, [completed_transaction | completed_transactions]}
          matched_quantity < order_quantity ->
            # generate the transaction here
            {lob, order, completed_transaction} = execute_buy_order(lob, order, matched_order)
            # pop the order
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            price_points = put_in(lob.price_points, [ask_min_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            # decrement the existing order
            order = %{order | quantity: order_quantity - matched_quantity}
            lob = lob
                  |> update_active_order(order) # updates the quantity of the current order
                  |> remove_active_order(popped_order) # remove the matched order
            price_time_match(order, lob, [completed_transaction | completed_transactions])
          matched_quantity > order_quantity ->
            {lob, order, completed_transaction} = execute_buy_order(lob, order, matched_order)
            # pop the order
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            # modify the quantity of the original order
            popped_order = %{popped_order | quantity: matched_quantity - order_quantity}
            # put new queue back
            price_points_queue = :queue.in(popped_order, price_points_queue)
            # put queue back in to limit order book
            price_points = put_in(lob.price_points, [ask_min_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            # put the queue back where it belongs
            lob = update_active_order(lob, popped_order)
            {lob, order, [completed_transaction | completed_transactions]}
        end
    end
  end
  def price_time_match(%Order{side: 0, price_in_cents: order_price_in_cents, quantity: order_quantity} = order,
                       %LimitOrderBook{price_points: price_points, ask_min_in_cents: ask_min_in_cents} = lob,
                       completed_transactions
  ) when order_price_in_cents < ask_min_in_cents do
    # we have exhausted all possible matches, queue the order
    {%LimitOrderBook{} = lob, %Order{} = order} = queue_order(lob, order)
    {lob, order, completed_transactions}
  end

@doc """
  FIFO Price-Time Matching Algorithm For Sell-Side Order
  """
  def price_time_match(%Order{side: 1, price_in_cents: order_price_in_cents, quantity: order_quantity} = order,
                       %LimitOrderBook{price_points: price_points, bid_max_in_cents: bid_max_in_cents} = lob,
                       completed_transactions
  ) when order_price_in_cents <= bid_max_in_cents do
    price_points_queue = Map.fetch!(price_points, bid_max_in_cents)
    # peek first item in queue and perform logic based on it
    case :queue.peek(price_points_queue) do
      :empty ->
        # when it's empty, we continue to decrement
        price_time_match(order, decrement_bid_max_in_cents(lob), completed_transactions)
      {:value, %Order{quantity: matched_quantity} = matched_order} ->
        cond do
          matched_quantity == order_quantity ->
            # pop the order off the queue
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            # remove the active order from the queue
            lob = remove_active_order(lob, popped_order)
            # set the price points map. this can definitely be refactored
            price_points = put_in(price_points, [bid_max_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            {lob, order, completed_transaction} = execute_sell_order(lob, order, popped_order)
            {lob, order, [completed_transaction | completed_transactions]}
          matched_quantity < order_quantity ->
            # generate the transaction here
            {lob, order, completed_transaction} = execute_sell_order(lob, order, matched_order)
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            price_points = put_in(price_points, [bid_max_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            # decrement the existing order
            order = %{order | quantity: order_quantity - matched_quantity}
            lob = lob
                  |> update_active_order(order) # update the quantity of the current order
                  |> remove_active_order(popped_order) # remove the matched order
            price_time_match(order, lob, [completed_transaction | completed_transactions])
          matched_quantity > order_quantity ->
            {lob, order, completed_transaction} = execute_sell_order(lob, order, matched_order)
            # pop the order
            {{:value, popped_order}, price_points_queue} = :queue.out(price_points_queue)
            # modify the quantity of the original order
            popped_order = %{popped_order | quantity: matched_quantity - order_quantity}
            # put new queue back
            price_points_queue = :queue.in(popped_order, price_points_queue)
            # put queue back in to limit order book
            price_points = put_in(price_points, [bid_max_in_cents], price_points_queue)
            lob = %{lob | price_points: price_points}
            # put the queue back where it belongs
            # initiate the trade here?
            {lob, order, [completed_transaction | completed_transactions]}
        end
    end
  end

  @doc """
  Base-Case for Price-Time Matching Algorithm when no prices are found
  """
  def price_time_match(%Order{side: 1, price_in_cents: order_price_in_cents} = order,
                       %LimitOrderBook{bid_max_in_cents: bid_max_in_cents} = lob,
                       completed_transactions
  ) when order_price_in_cents > bid_max_in_cents do
    # we have exhausted iterating through all the price points, queue the order
    {%LimitOrderBook{} = lob, %Order{} = order} = queue_order(lob, order)
    {lob, order, completed_transactions}
  end

  @doc """
  Queues an %Order{} in to the correct price_point
  """
  def queue_order(%LimitOrderBook{} = lob, %Order{} = order) do
    lob = lob
          |> insert_order_in_queue(order) # insert order in to respective queue
          |> insert_active_order(order) # insert order in to global list of orders
          |> set_bid_max_in_cents(order) # update bid_max_in_cents
          |> set_ask_min_in_cents(order) # update ask_min_in_cents
    # return the final lob and order
    {lob, order}
  end

  def insert_order_in_queue(%LimitOrderBook{price_points: price_points} = lob,
                            %Order{price_in_cents: price_in_cents} = order
  ) do
    # fetch the price points keyed at price_in_cents
    queue = Map.fetch!(price_points, price_in_cents)
    # insert in to queue
    queue = :queue.in(order, queue)
    # now put back inside price_points
    price_points = put_in(price_points, [price_in_cents], queue)
    %{lob | price_points: price_points}
  end

  @doc """
  Handle the 3 cases for executing on a buy order.
  In all 3 cases, we want to generate a transaction

  a) increments global transaction_id
  b) creates CompletedTransaction & sets transaction_id on completed_transaction
  c)
  """
  # def execute_buy_order(%LimitOrderBook{} = lob, %Order{} = order, %Order{} = matched_order) when quantity == matched_quantity do
  # {lob, transaction} = generate_transaction(lob, order, matched_order, :full_filled_buy_order)
  # {lob, order, transaction}
  # end
  def execute_buy_order(%LimitOrderBook{} = lob,
                        %Order{quantity: quantity} = order,
                        %Order{quantity: matched_quantity} = matched_order
  ) when quantity <= matched_quantity do
    {lob, transaction} = generate_transaction(lob, order, matched_order, :full_fill_buy_order)
    {lob, order, transaction}
  end
  def execute_buy_order(%LimitOrderBook{} = lob,
                        %Order{quantity: quantity} = order,
                        %Order{quantity: matched_quantity} = matched_order
  ) when quantity > matched_quantity do
    {lob, transaction} = generate_transaction(lob, order, matched_order, :partial_fill_buy_order)
    {lob, order, transaction}
  end

  def execute_sell_order(%LimitOrderBook{} = lob,
                         %Order{quantity: quantity} = order,
                         %Order{quantity: matched_quantity} = matched_order
  ) when quantity <= matched_quantity do
    {lob, transaction} = generate_transaction(lob, order, matched_order, :full_fill_sell_order)
    {lob, order, transaction}
  end
  def execute_sell_order(%LimitOrderBook{} = lob,
                         %Order{quantity: quantity} = order,
                         %Order{quantity: matched_quantity} = matched_order
  ) when quantity > matched_quantity do
    {lob, transaction} = generate_transaction(lob, order, matched_order, :partial_sell_buy_order)
    {lob, order, transaction}
  end

  def generate_transaction(%LimitOrderBook{} = lob, %Order{} = order, %Order{} = matched_order, type) do
    {transaction_id, lob} = generate_transaction_id(lob)
    completed_transaction = %CompletedTransaction{
      transaction_id: transaction_id,
      buy_order: order,
      sell_order: matched_order,
      type: type,
      acknowledged_at: :os.system_time(:micro_seconds),
    }
    completed_transactions = completed_transaction |> Map.put(transaction_id, completed_transaction)

    # IO.puts "---"
    # IO.puts "execute buy order"
    # IO.puts "EXECUTE: txn_id:#{transaction_id} trader: #{order.trader_id} BUY trader:#{matched_order.trader_id} #{order.price_in_cents} @ #{order.quantity}"
    # IO.puts "---"
    # IO.inspect completed_transaction

    lob = %{lob | completed_transactions: completed_transactions}
    {lob, completed_transaction}
  end



  @doc """
  Inserts the order in to the active list
  """
  def insert_active_order(%LimitOrderBook{active_orders: active_orders} = lob, %Order{order_id: order_id} = order) do
    active_orders =
      active_orders
      |> Map.put(order_id, order)
      |> Map.update!(:count, &(&1 + 1))
    %{lob | active_orders: active_orders}
  end

  def update_active_order(%LimitOrderBook{active_orders: active_orders} = lob, %Order{order_id: order_id} = order) do
    active_orders =
      active_orders
      |> Map.put(order_id, order)
    %{lob | active_orders: active_orders}
  end

  @doc """
  Remove an active order from LimitOrderBook
  """
  def remove_active_order(%LimitOrderBook{active_orders: active_orders} = lob, %Order{order_id: order_id}) do
    active_orders =
      active_orders
      |> Map.delete(order_id) # delete the order_id
      |> Map.update!(:count, &(&1 - 1)) # decrement the count
    %{lob | active_orders: active_orders}
  end

  @doc """
  Generate an order_id for an order
  """
  def generate_order_id(%LimitOrderBook{global_order_id: global_order_id} = lob) do
    new_order_id = global_order_id + 1
    {new_order_id, %{lob | global_order_id: new_order_id}}
  end

  @doc """
  Generate a transaction_id for an order
  """
  def generate_transaction_id(%LimitOrderBook{transaction_id: transaction_id} = lob) do
    new_transaction_id = transaction_id + 1
    {new_transaction_id, %{lob | transaction_id: new_transaction_id}}
  end

  @doc """
  Acknowledge an order has been received by server and add a timestamp
  """
  def acknowledge_order(%LimitOrderBook{} = lob, %Order{} = order) do
    {order_id, lob} = generate_order_id(lob) # generate a transaction_id for this order
    order =
      order
      |> Map.put(:acknowledged_at, :os.system_time(:micro_seconds))
      |> Map.put(:order_id, order_id)
    {lob, order}
  end

  def set_order_id(%Order{} = order, %LimitOrderBook{transaction_id: transaction_id}) do
    %{order | order_id: transaction_id}
  end

@doc """
  sets the bid_max_in_cents
  """
  def set_bid_max_in_cents(%LimitOrderBook{bid_max_in_cents: bid_max_in_cents} = lob,
                           %Order{side: 0, price_in_cents: price_in_cents}
  ) when bid_max_in_cents < price_in_cents do
    %{lob | bid_max_in_cents: price_in_cents}
  end
  def set_bid_max_in_cents(%LimitOrderBook{} = lob, %Order{}), do: lob

  def set_ask_min_in_cents(
    %LimitOrderBook{ask_min_in_cents: ask_min_in_cents} = lob,
    %Order{side: 1, price_in_cents: price_in_cents}
  ) when ask_min_in_cents > price_in_cents do
    %{lob | ask_min_in_cents: price_in_cents}
  end
  def set_ask_min_in_cents(%LimitOrderBook{} = lob, %Order{}), do: lob

  def increment_ask_min_in_cents(%LimitOrderBook{ask_min_in_cents: ask_min_in_cents} = lob) do
    %{lob | ask_min_in_cents: ask_min_in_cents + 1}
  end

  def decrement_bid_max_in_cents(%LimitOrderBook{bid_max_in_cents: bid_max_in_cents} = lob) do
    %{lob | bid_max_in_cents: bid_max_in_cents - 1}
  end

end
