defmodule WuExchangeBackendTest do
  use ExUnit.Case
  doctest WuExchangeBackend

  test "greets the world" do
    assert WuExchangeBackend.hello() == :world
  end
end
