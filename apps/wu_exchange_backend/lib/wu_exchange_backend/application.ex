defmodule WuExchangeBackend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    # List all child processes to be supervised
    children = [
      supervisor(Registry, [:unique, :matching_engine_registry]),
      # Starts a worker by calling: WuExchangeBackend.Worker.start_link(arg)
      # {WuExchangeBackend.Worker, arg}

      # create a supervised application for WUXC, TSLA, GOOG
      supervisor(WuExchangeBackend.MatchingEngine, [:WUXC, 100_000], id: :WUXC),
      supervisor(WuExchangeBackend.MatchingEngine, [:TSLA, 100_000], id: :TSLA),
      supervisor(WuExchangeBackend.MatchingEngine, [:GOOG, 125_000], id: :GOOG),

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WuExchangeBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
