defmodule E.Endpoint do
  use Plug.Router
  use Plug.ErrorHandler
  require Logger

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/:table" do
    # TODO encode in sqlite?
    results = conn.params |> E.Query.all() |> Jason.encode_to_iodata!()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, results)
  end
end
