alias WuExchangeBackend.{
  MatchingEngine,
  Order
}

# do all setup required below
{:ok, pid_1} = MatchingEngine.start_link()
{:ok, pid_2} = MatchingEngine.start_link()
{:ok, pid_3} = MatchingEngine.start_link()

# setup MatchingEngine for a delete
{:ok, pid_4} = MatchingEngine.start_link()


Benchee.run(%{
  "insert and delete a sell order": fn ->
    {:ok, %Order{order_id: order_id_4}} = 
      MatchingEngine.buy_limit_order(pid: pid_4, trader_id: 1, price_in_cents: 100, quantity: 100)
    {:ok, _} = MatchingEngine.cancel_order(pid_4, order_id_4)
  end,
  # "insert and delete 100 sell orders" fn ->
  # results =
  # 1..10 |> Enum.map(fn(i) ->
  # {:ok, %Order{order_id: order_id}} = MatchingEngine.sell_limit_order
  # end)
  # end,
  "insert a buy limit order": fn -> 
    MatchingEngine.buy_limit_order(pid: pid_1, trader_id: 1, price_in_cents: 100, quantity: 100)
  end,
  "insert a sell limit order": fn ->
    MatchingEngine.sell_limit_order(pid: pid_1, trader_id: 1, price_in_cents: 100, quantity: 100)
  end,
  "insert 10 sell limit order": fn ->
    for _ <- 0..10 do
      MatchingEngine.sell_limit_order(pid: pid_1, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
  "insert 10 buy limit order": fn ->
    for _ <- 0..10 do
      MatchingEngine.buy_limit_order(pid: pid_2, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
  "insert 10 matching orders": fn ->
    for _ <- 0..10 do
      MatchingEngine.buy_limit_order(pid: pid_3, trader_id: 1, price_in_cents: 100, quantity: 100)
      MatchingEngine.sell_limit_order(pid: pid_3, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
  "insert 1000 sell limit order": fn ->
    for _ <- 0..1000 do
      MatchingEngine.sell_limit_order(pid: pid_1, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
  "insert 1000 buy limit order": fn ->
    for _ <- 0..1000 do
      MatchingEngine.buy_limit_order(pid: pid_2, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
  "insert 1000 matching orders": fn ->
    for _ <- 0..1000 do
      MatchingEngine.buy_limit_order(pid: pid_3, trader_id: 1, price_in_cents: 100, quantity: 100)
      MatchingEngine.sell_limit_order(pid: pid_3, trader_id: 1, price_in_cents: 100, quantity: 100)
    end
  end,
},
formatters: [
  Benchee.Formatters.HTML
  ]
)
