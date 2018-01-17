defmodule WuExchangeBackend.MatchingEngineTest do
  use ExUnit.Case, async: false
  doctest WuExchangeBackend

  alias WuExchangeBackend.{
    MatchingEngine,
    Order,
    LimitOrderBook,
    CompletedTransaction,
  }

  setup do
    ticker = :test
    {:ok, _server_pid} = MatchingEngine.start_link(ticker, 100_000)
    {:ok, ticker: ticker}
  end

  describe "execute_buy_order/3" do
    test "correctly creates a %CompletedTransaction" do
      lob = %LimitOrderBook{
        price_points: Enum.reduce(0..10_000, %{}, fn(x, acc) -> Map.put(acc, x, :queue.new()) end),
        transaction_id: 0,
        max_price_in_cents: 0,
        bid_max_in_cents: 0,
        ask_min_in_cents: 0,
      }
      sell_order = %Order{order_id: 1, trader_id: 1, quantity: 500, price_in_cents: 500}
      buy_order = %Order{order_id: 2, trader_id: 2, quantity: 500, price_in_cents: 500}
      
      assert {
        %LimitOrderBook{} = lob,
        %Order{order_id: 2} = buy_order,
        %CompletedTransaction{transaction_id: 1} = completed_transcation,
      } = MatchingEngine.execute_buy_order(lob, buy_order, sell_order)
    end

  end

  describe "Sell Limit Order" do

    test "sell limit orders are stored in active_orders", %{ticker: ticker} do
    end

    test "creating sell order for 0 cents is rejected", %{ticker: ticker} do
      assert {:ok, :rejected} = MatchingEngine.sell_limit_order(ticker: ticker, trader_id: 1, price_in_cents: 0, quantity: 20)
    end

    test "creatting a sell order for 0 quantity is rejected", %{ticker: ticker} do
      assert {:ok, :rejected} = MatchingEngine.sell_limit_order(ticker: ticker, trader_id: 1, price_in_cents: 10, quantity: 0)
    end
  
    test "cancel/2 removes a sell order from active orders and price_points", %{ticker: ticker} do
      # create a sell order
      {:ok, %Order{order_id: order_id} = order} = MatchingEngine.sell_limit_order(ticker: ticker, trader_id: 1, price_in_cents: 50, quantity: 20)
      # now cancel it
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, cancelled_order} = MatchingEngine.cancel(ticker, order_id)
      assert {:ok, 0} = MatchingEngine.active_order_count(ticker)
      assert cancelled_order.order_id == order_id
    end

    test "cancel/2 removes a partially matched order", %{ticker: ticker} do
      {:ok, %Order{}} = MatchingEngine.buy_limit_order(
        ticker: ticker, trader_id: 1, price_in_cents: 50, quantity: 20
      )
      {:ok, %Order{order_id: order_id} = order} = MatchingEngine.sell_limit_order(
        ticker: ticker, trader_id: 1, price_in_cents: 50, quantity: 30
      )
      # this should result in queuing an order for 50 cents at quantity 10
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, %Order{order_id: canceled_order_id}} = MatchingEngine.cancel(ticker, order_id)
      assert canceled_order_id == order_id
      assert {:ok, 0} = MatchingEngine.active_order_count(ticker)
    end

    test "cancel/2 on an sell_order that does not belong to you is rejected", %{ticker: ticker} do
      assert {:ok, %Order{}} = MatchingEngine.sell_limit_order(
        ticker: ticker, trader_id: 1, price_in_cents: 50, quantity: 20
      )
    end

    test "sell x buy match creates a transaction", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, %Order{} = buy_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, 0} = MatchingEngine.active_order_count(ticker)
    end

    test "sell x buy match creates a transaction with greater sell quantity", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 50,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, %Order{} = buy_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
    end

    test "sell x buy match creates a transaction with less quantity", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 50,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, %Order{} = buy_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 100,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
    end

    test "transaction_id is correctly incremented with new order" do
    end

    test "price_time_match/3 correctly match when both orders are of equivalent quantity" do
      lob = %LimitOrderBook{
        price_points: Enum.reduce(0..10_000, %{}, fn(x, acc) -> Map.put(acc, x, :queue.new()) end),
        transaction_id: 0,
        max_price_in_cents: 0,
        bid_max_in_cents: 0,
        ask_min_in_cents: 0,
      }
      order_price_in_c = 50
      # queue an order inside the LOB
      buy_order = %Order{side: 0, quantity: 10, trader_id: 1, price_in_cents: order_price_in_c}
      {
        %LimitOrderBook{price_points: price_points, bid_max_in_cents: bid_max_in_cents} = lob,
        %Order{} = order
      } = MatchingEngine.queue_order(lob, buy_order)
      {:ok, price_points_queue} = Map.fetch(price_points, order_price_in_c)
      # make sure the at price_point 50, the order exists
      assert :queue.len(price_points_queue) == 1
      sell_order = %Order{side: 1, quantity: 10, price_in_cents: order_price_in_c, trader_id: 2}
      {lob, order, accumulator} = MatchingEngine.price_time_match(sell_order, lob, [])
      {:ok, price_points_queue} = Map.fetch(lob.price_points, order_price_in_c)
      assert :queue.len(price_points_queue) == 0
    end

    test "get_list_of_orders/1 when buy_order.quantity > sell_order.quantity" do
      lob = %LimitOrderBook{
        price_points: Enum.reduce(0..10_000, %{}, fn(x, acc) -> Map.put(acc, x, :queue.new()) end),
        transaction_id: 0,
        max_price_in_cents: 0,
        bid_max_in_cents: 0,
        ask_min_in_cents: 0,
      }
      order_price_in_c = 52
      # queue an order inside the LOB
      buy_order = %Order{side: 0, quantity: 50, trader_id: 1, price_in_cents: order_price_in_c}
      {
        %LimitOrderBook{price_points: price_points, bid_max_in_cents: bid_max_in_cents} = lob,
        %Order{} = order
      } = MatchingEngine.queue_order(lob, buy_order)
      {:ok, price_points_queue} = Map.fetch(price_points, order_price_in_c)
      # make sure the at price_point 50, the order exists
      assert :queue.len(price_points_queue) == 1
      sell_order = %Order{side: 1, quantity: 10, price_in_cents: order_price_in_c, trader_id: 2}
      {lob, order, accumulator} = MatchingEngine.price_time_match(sell_order, lob, [])
    end

    test "price_time_match/3 correctly matches an order when buy_order.quantity < sell_order.quantity" do
      lob = %LimitOrderBook{
        price_points: Enum.reduce(0..10_000, %{}, fn(x, acc) -> Map.put(acc, x, :queue.new()) end),
        transaction_id: 0,
        max_price_in_cents: 0,
        bid_max_in_cents: 0,
        ask_min_in_cents: 0,
      }
      order_price_in_c = 52
      # queue an order inside the LOB
      buy_order = %Order{side: 0, quantity: 50, trader_id: 1, price_in_cents: order_price_in_c}
      {
        %LimitOrderBook{price_points: price_points, bid_max_in_cents: bid_max_in_cents} = lob,
        %Order{} = order
      } = MatchingEngine.queue_order(lob, buy_order)
      {:ok, price_points_queue} = Map.fetch(price_points, order_price_in_c)
      # make sure the at price_point 50, the order exists
      assert :queue.len(price_points_queue) == 1
      sell_order = %Order{side: 1, quantity: 25, price_in_cents: order_price_in_c, trader_id: 2}
      {lob, order, accumulator} = MatchingEngine.price_time_match(sell_order, lob, [])
      sell_order = %Order{side: 1, quantity: 25, price_in_cents: order_price_in_c, trader_id: 3}
      {lob, order, accumulator} = MatchingEngine.price_time_match(sell_order, lob, [])
      # make sure new quantity matches
      {:ok, price_points_queue} = Map.fetch(lob.price_points, order_price_in_c)
      assert :queue.len(price_points_queue) == 0
    end

    test "is rejected when exchange server is halted", %{ticker: ticker} do
    end

    test "is rejected when max_price_in_cents is greater than limit", %{ticker: ticker} do
      assert {:reject, _} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 1_000_000,
        quantity: 1,
      )
    end

    test "is queued when there are no existing buy limit orders that match", %{ticker: ticker} do
      # create a sell limit order
      price_in_cents = 5012
      assert {:ok, _} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: price_in_cents,
        quantity: 25,
      )
      # now get the limit order book
      {:ok, price_points_list} = MatchingEngine.orders_at_price_point(ticker, 5012)
      assert length(price_points_list) == 1
    end

    test "is queued when there are existing buy limit orders that do not match", %{ticker: ticker} do
      assert {:ok, _} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 5012,
        quantity: 25,
      )
      assert {:ok, _} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 25,
      )
      # now get the limit order book
      {:ok, price_points_list} = MatchingEngine.orders_at_price_point(ticker, 5012)

      # assert length(price_points_list) == 2
    end

    test "is executed when there is a matching buy order", %{ticker: ticker} do
    end

    test "increments transaction_count when a trade is executed" do
    end

  end

  describe "Buy Limit Order" do

    test "buy limit orders are stored in active_orders", %{ticker: ticker} do
    end
  
    test "buy x sell match creates a transaction", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, %Order{} = buy_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, 0} = MatchingEngine.active_order_count(ticker)
    end

    test "buy x sell match creates a transaction with greater sell quantity", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 50,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, %Order{} = buy_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 25,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
    end

    test "buy x sell match creates a transaction with less quantity", %{ticker: ticker} do
      assert {:ok, %Order{} = sell_order} = MatchingEngine.buy_limit_order(
        ticker: ticker,
        trader_id: 1,
        price_in_cents: 125,
        quantity: 50,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, %Order{} = buy_order} = MatchingEngine.sell_limit_order(
        ticker: ticker,
        trader_id: 2,
        price_in_cents: 125,
        quantity: 100,
      )
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
    end

    test "matches when crossed with a corresponding sell order", %{ticker: ticker} do
      {:ok, %Order{order_id: 1} = sell_order} = MatchingEngine.sell_limit_order(ticker: ticker, trader_id: 2, price_in_cents: 5000, quantity: 250)
      {:ok, %Order{} = buy_order} = MatchingEngine.buy_limit_order(ticker: ticker, trader_id: 1, price_in_cents: 5000, quantity: 100)
    end

    test "is queued when there are no existing sell limit orders that match", %{ticker: ticker} do
      {:ok, %Order{} = order} = MatchingEngine.buy_limit_order(ticker: ticker, trader_id: 2, price_in_cents: 5000, quantity: 250)
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
    end

    test "cancel removes a buy order from active orders and price_points", %{ticker: ticker} do
      # create a sell order
      {:ok, %Order{order_id: order_id} = order} = MatchingEngine.buy_limit_order(ticker: ticker, trader_id: 1, price_in_cents: 50, quantity: 20)
      # now cancel it
      assert {:ok, 1} = MatchingEngine.active_order_count(ticker)
      assert {:ok, cancelled_order} = MatchingEngine.cancel(ticker, order_id)
      assert {:ok, 0} = MatchingEngine.active_order_count(ticker)
      assert cancelled_order.order_id == order_id
    end

    test "cancelling an order that does not exist returns :fail", %{ticker: ticker} do
      assert {:ok, :fail} = MatchingEngine.cancel(ticker, 255)
    end

  end


  test "Order Book Process Starts", %{ticker: ticker} do
  end

  test "cancel an order", %{ticker: ticker} do
  end


  test "can list current order book status", %{ticker: ticker} do
    assert {:ok, %{} = order_book} = MatchingEngine.status(ticker)
  end

end
