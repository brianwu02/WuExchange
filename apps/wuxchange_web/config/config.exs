# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :wuxchange_web,
  namespace: WuxchangeWeb,
  ecto_repos: [WuxchangeWeb.Repo]

# Configures the endpoint
config :wuxchange_web, WuxchangeWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "daSeL1OWJxgPJRu/TzIjfmzBPUHgeywJO+7HjZA1AM7vBFSxQWEBevphdornYDH+",
  render_errors: [view: WuxchangeWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: WuxchangeWeb.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :wuxchange_web, :generators,
  context_app: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
