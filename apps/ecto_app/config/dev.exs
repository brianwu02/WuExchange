use Mix.Config

# Configure your database
config :ecto_app, EctoApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  # username: "postgres",
  # password: "postgres",
  # database: "ecto_app_dev",
  # hostname: "localhost",
  username: "rebelbase_dev",
  password: "password",
  database: "rebelbase_dev",
  hostname: "localhost",
  pool_size: 10
