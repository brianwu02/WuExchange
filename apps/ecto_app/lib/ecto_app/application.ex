defmodule EctoApp.Application do
  @moduledoc """
  The EctoApp Application Service.

  The ecto_app system business domain lives in this application.

  Exposes API to clients such as the `EctoAppWeb` application
  for use in channels, controllers, and elsewhere.
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link([
      supervisor(EctoApp.Repo, []),
    ], strategy: :one_for_one, name: EctoApp.Supervisor)
  end
end
