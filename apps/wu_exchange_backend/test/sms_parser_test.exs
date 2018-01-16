defmodule WuExchangeBackend.SMSParserTest do
  use ExUnit.Case
  doctest WuExchangeBackend.SMSParser

  alias WuExchangeBackend.SMSParser

  describe "Invalid SMS format" do

    test "returns an error" do
      assert {:fail, _} = SMSParser.parse_sms("this is a invalid command")
    end

    test "returns another error" do
      # assert {:fail, _} = SMSParser.parse_sms("BUY twenty of x")
    end

    test "incorrect buy limit" do
    end

    test "incorrect sell limit" do
    end

  end

  describe "incoming buy limit order sms text" do

    test "buy order is correctly parsed" do
      example_sms_content = "BUY 50 WUXC @ $45.50"
      assert {:ok, %{
        order_type: :buy,
        ticker: :wuxc,
        quantity: 50,
        price_in_cents: 4550,
      }} = SMSParser.parse_sms(example_sms_content)
    end

  end

  describe "incoming sell limit order sms text" do
    
    test "sell order is correctly parsed" do
      example_sms_content = "SELL 25 WUXC @ $25.50"
      assert {:ok, %{
        order_type: :sell,
        ticker: :wuxc,
        quantity: 25,
        price_in_cents: 2550,
      }} = SMSParser.parse_sms(example_sms_content)

    end

  end

  describe "incoming cancel order sms text" do

    test "cancel order is correctly parsed" do
      example_sms_content = "CANCEL 25"
      assert {:ok, %{order_id: order_id}} = SMSParser.parse_sms(example_sms_content)
    end

  end

end
