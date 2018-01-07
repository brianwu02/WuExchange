defmodule ExchangeBackendTest do
  use ExUnit.Case
  doctest ExchangeBackend

  test "greets the world" do
    assert ExchangeBackend.hello() == :world
  end
end
