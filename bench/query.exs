# TODO bench query string parsing
Benchee.run(
  %{
    "/people" => fn ->
      E.Query.build(%{"table" => "people"})
    end,
    "/people?age=lt.13" => fn ->
      E.Query.build(%{"table" => "people", "age" => "lt.13"})
    end,
    "/people?age=gte.18&student=is.true" => fn ->
      E.Query.build(%{"table" => "people", "age" => "gte.18", "student" => "is.true"})
    end
  },
  memory_time: 2
)
