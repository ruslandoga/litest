defmodule ETest do
  use E.ConnCase

  test "it works" do
    E.Repo.insert_all("people", [
      %{name: "John0", age: 10, student: 1},
      %{name: "John1", age: 13, student: 1},
      %{name: "John2", age: 18, student: 1},
      %{name: "John3", age: 18, student: 0}
    ])

    conn = dispatch(conn(:get, "/people"))
    assert conn.status == 200

    assert Jason.decode!(conn.resp_body) == [
             %{"age" => 10, "id" => 1, "name" => "John0", "student" => true},
             %{"age" => 13, "id" => 2, "name" => "John1", "student" => true},
             %{"age" => 18, "id" => 3, "name" => "John2", "student" => true},
             %{"age" => 18, "id" => 4, "name" => "John3", "student" => false}
           ]

    conn = dispatch(conn(:get, "/people?age=lt.13"))
    assert conn.status == 200

    assert Jason.decode!(conn.resp_body) == [
             %{"age" => 10, "id" => 1, "name" => "John0", "student" => true}
           ]

    conn = dispatch(conn(:get, "/people?age=gte.18&student=is.true"))
    assert conn.status == 200

    assert Jason.decode!(conn.resp_body) == [
             %{"age" => 18, "id" => 3, "name" => "John2", "student" => true}
           ]
  end

  test "query" do
    assert %{"table" => "people"} |> E.Query.build() |> to_sql() ==
             {~s[SELECT p0."id", p0."name", p0."age", p0."student" FROM "people" AS p0], []}

    assert %{"table" => "people", "age" => "lt.13"} |> E.Query.build() |> to_sql() ==
             {~s[SELECT p0."id", p0."name", p0."age", p0."student" FROM "people" AS p0 WHERE (1 AND (p0."age" < CAST(? AS INTEGER)))],
              [13]}

    assert %{"table" => "people", "age" => "gte.18", "student" => "is.true"}
           |> E.Query.build()
           |> to_sql() ==
             {~s[SELECT p0."id", p0."name", p0."age", p0."student" FROM "people" AS p0 WHERE ((1 AND (p0."age" >= CAST(? AS INTEGER))) AND p0."student" is CAST(? AS BOOLEAN))],
              [18, 1]}
  end

  test "load" do
    E.Repo.insert_all("people", [
      %{name: "John0", age: 10, student: 1},
      %{name: "John1", age: 13, student: 1},
      %{name: "John2", age: 18, student: 1},
      %{name: "John3", age: 18, student: 0}
    ])

    assert E.Query.all(%{"table" => "people"}) == [
             %{age: 10, id: 1, name: "John0", student: true},
             %{age: 13, id: 2, name: "John1", student: true},
             %{age: 18, id: 3, name: "John2", student: true},
             %{age: 18, id: 4, name: "John3", student: false}
           ]
  end

  defp to_sql(query) do
    Ecto.Adapters.SQL.to_sql(:all, E.Repo, query)
  end

  test "schema" do
    assert E.Query.fetch_schema() == [
             {"people",
              [
                %{aname: :id, sname: "id", type: :integer},
                %{aname: :name, sname: "name", type: :string},
                %{aname: :age, sname: "age", type: :integer},
                %{aname: :student, sname: "student", type: :boolean}
              ]},
             {"schema_migrations",
              [
                %{aname: :version, sname: "version", type: :integer},
                %{aname: :inserted_at, sname: "inserted_at", type: :naive_datetime}
              ]}
           ]

    assert E.Query.columns("people") == [
             %{aname: :id, sname: "id", type: :integer},
             %{aname: :name, sname: "name", type: :string},
             %{aname: :age, sname: "age", type: :integer},
             %{aname: :student, sname: "student", type: :boolean}
           ]

    assert :persistent_term.get({E.Query, :known}) == ["schema_migrations", "people"]
  end
end
