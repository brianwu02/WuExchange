use Mix.Config

# Configure your database
config :ecto_app, EctoApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "rebelbase_dev",
  password: "password",
  database: "rebelbase_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
