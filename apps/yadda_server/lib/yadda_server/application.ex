defmodule YaddaServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")


    children = [
      {Task.Supervisor, name: YaddaServer.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> YaddaServer.accept(port) end}, restart: :permanent)
      # {Task, fn -> YaddaServer.accept(port) end}
      # Starts a worker by calling: YaddaServer.Worker.start_link(arg)
      # {YaddaServer.Worker, arg}
    ]


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: YaddaServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
