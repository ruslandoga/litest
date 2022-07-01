defmodule E.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Plug.Test
      import E.{DataCase, ConnCase}
      alias E.Repo
    end
  end

  setup tags do
    E.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint_opts E.Endpoint.init([])

  def dispatch(conn) do
    E.Endpoint.call(conn, @endpoint_opts)
  end
end
