use Mix.Config

config :ecto_app, ecto_repos: [EctoApp.Repo]

import_config "#{Mix.env}.exs"
