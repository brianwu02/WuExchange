defmodule WuExchangeBackend.SMSParser do
  @doc """
  Parses SMS messages in to commands

  #TODO: add proper error handling, right now only handles correct stuff
  """

  @doc """
  iex> sms_text = "BUY 50 TSLA @ $45.50"
  "BUY 50 TSLA @ $45.50"
  # iex> {:ok, _} = WuExchangeBackend.SMSParser.parse_sms(sms_text)
  # {:ok, _}
  """
  def parse_sms(sms_text) do
    sms_text
    |> String.split(" ")
    |> Enum.map(&String.downcase/1)
    |> generate_order()
  end

  def generate_order([order_type | rest] = list_of_commands) do
    case order_type do
      "buy" ->
        {:ok, order_map} = parse_buy_sell_order(rest)
        {:ok, Map.put(order_map, :order_type, :buy)}
      "sell" ->
        {:ok, order_map} = parse_buy_sell_order(rest)
        {:ok, Map.put(order_map, :order_type, :sell)}
      "cancel" ->
        {:ok, order_map} = parse_cancel_order(rest)
      _ ->
        {:fail, "unknown command type: #{order_type}"}
    end
  end

  @doc """
  rest_of_list format: [
    "50", => quantity 
    "TSLA", => ticker_symbol
    "$", => currency, we can ignore this
    "25.50" = price_in_dollars
  ]
  """
  def parse_buy_sell_order(rest_of_list) do
    quantity = Enum.at(rest_of_list, 0) |> String.to_integer()
    ticker = Enum.at(rest_of_list, 1) |> String.to_atom
    price_in_cents = Enum.at(rest_of_list, 3)
                     |> String.replace("$", "") # remove the $
                     |> String.to_float # convert to float
                     |> (&(&1 * 100)).() # multiply by 100
                     |> round # convert to integer by rounding
    {:ok, %{quantity: quantity, ticker: ticker, price_in_cents: price_in_cents}}
  end

  @doc """
  rest_of_list format ["50", "TSLA", "$", "PRICE"]
  """
  def parse_cancel_order(rest_of_list) do
    order_id = rest_of_list
               |> Enum.at(0)
               |> String.to_integer()

    {:ok, %{order_id: order_id}}
  end

end
