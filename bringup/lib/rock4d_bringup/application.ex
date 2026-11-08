defmodule Rock4dBringup.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: Rock4dBringup.Worker.start_link(arg)
        # {Rock4dBringup.Worker, arg},
      ] ++ target_children()

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rock4dBringup.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      init_complete()
      {:ok, pid}
    end
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children() do
      [
        # Children that only run on the host during development or test.
        # In general, prefer using `config/host.exs` for differences.
        #
        # Starts a worker by calling: Host.Worker.start_link(arg)
        # {Host.Worker, arg},
      ]
    end

    defp init_complete(), do: :ok
  else
    # The startup guard is off so A/B revert tests can leave a slot
    # unvalidated, but it is also what completes the heart handshake;
    # without this nerves_heart reboots the board at 600 s.
    defp init_complete(), do: Nerves.Runtime.Heart.init_complete()

    defp target_children() do
      [
        # Children for all targets except host
        # Starts a worker by calling: Target.Worker.start_link(arg)
        # {Target.Worker, arg},
      ]
    end
  end
end
