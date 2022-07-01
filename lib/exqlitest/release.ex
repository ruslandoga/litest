defmodule E.Release do
  defmodule SchemaRefresh do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(_opts) do
      E.Query.refresh_schema()
      :ignore
    end
  end
end
