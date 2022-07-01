defmodule E.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    endpoint_config = Application.fetch_env!(:e, E.Endpoint)
    http_options = Keyword.fetch!(endpoint_config, :http)

    children =
      [
        E.Repo,
        E.Release.SchemaRefresh,
        if http_options[:server] do
          {Plug.Cowboy, scheme: :http, plug: E.Endpoint, options: http_options}
        end
      ]
      |> Enum.reject(&is_nil/1)

    Supervisor.start_link(children, strategy: :one_for_one, name: E.Supervisor)
  end
end
