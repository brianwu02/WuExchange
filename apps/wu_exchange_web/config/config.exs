# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :wu_exchange_web,
  namespace: WuExchangeWeb

# Configures the endpoint
config :wu_exchange_web, WuExchangeWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "0ZBv58TdKu6Rm2fn0EEP4rNplITP5Xlq2n23GomKSdGwatco2u2WFl2zF2Hz0qLP",
  render_errors: [view: WuExchangeWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: WuExchangeWeb.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :wu_exchange_web, :generators,
  context_app: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
