defmodule E.Query do
  @moduledoc """
  A postgrest parser / query builder.
  """

  import Ecto.Query

  def refresh_schema do
    prev = :persistent_term.get({__MODULE__, :known}, [])

    new =
      Enum.reduce(fetch_schema(), [], fn {table, columns}, acc ->
        :persistent_term.put({__MODULE__, table}, columns)
        [table | acc]
      end)

    :ok = :persistent_term.put({__MODULE__, :known}, new)
    :ok = Enum.each(prev -- new, fn name -> :persistent_term.erase({__MODULE__, name}) end)

    new
  end

  def fetch_schema do
    tables_q =
      "sqlite_master"
      |> where([t], t.type in ["table", "view"])
      |> where([t], not like(t.name, "sqlite_%"))
      |> select([t], map(t, [:name, :type]))

    columns_q =
      "tables"
      |> join(:left, [t], p in fragment("pragma_table_info(?)", t.name))
      |> select([t, p], %{table_name: t.name, name: p.name, type: p.type})

    "columns"
    |> with_cte("tables", as: ^tables_q)
    |> with_cte("columns", as: ^columns_q)
    |> select([c], [c.table_name, c.name, c.type])
    |> E.Repo.all()
    |> Enum.group_by(fn [table_name | _] -> table_name end, fn [_table_name | rest] -> rest end)
    |> Enum.map(fn {table, columns} ->
      columns =
        Enum.map(columns, fn [name, type] ->
          %{type: type(type), aname: String.to_atom(name), sname: name}
        end)

      {table, columns}
    end)
  end

  # TODO maybe only work with strict? https://www.sqlite.org/stricttables.html
  defp type("INTEGER"), do: :integer
  defp type("TEXT"), do: :string
  defp type("BOOLEAN"), do: :boolean
  defp type("REAL"), do: :float
  defp type("NUMERIC"), do: :float
  defp type("BLOB"), do: :binary
  defp type("TEXT_DATETIME"), do: :naive_datetime
  defp type("DECIMAL"), do: :decimal

  def columns(table) do
    :persistent_term.get({__MODULE__, table}, nil)
  end

  # https://postgrest.org/en/stable/api.html
  def build(%{"table" => table} = params) do
    if columns = columns(table) do
      selected = selected(params["select"], columns)

      table
      |> where(^filter_where(params, columns))
      |> order_by(^filter_order_by(params["order"], columns))
      |> select([t], map(t, ^Enum.map(selected, & &1.aname)))
    end
  end

  def all(%{"table" => table} = params) do
    if columns = columns(table) do
      selected = selected(params["select"], columns)
      types = Map.new(selected, fn column -> {column.aname, column.type} end)

      table
      |> where(^filter_where(params, columns))
      |> order_by(^filter_order_by(params["order"], columns))
      |> select([t], map(t, ^Enum.map(selected, & &1.aname)))
      |> E.Repo.all()
      # TODO
      |> Enum.map(&E.Repo.load(types, &1))
    end
  end

  # https://postgrest.org/en/stable/api.html#operators
  # TODO cleanup
  defp filter_where(params, columns) do
    Enum.reduce(params, dynamic(true), fn
      {column, "eq." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) == type(^value, ^column.type))
        else
          dynamic
        end

      {column, "gt." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) > type(^value, ^column.type))
        else
          dynamic
        end

      {column, "gte." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) >= type(^value, ^column.type))
        else
          dynamic
        end

      {column, "lt." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) < type(^value, ^column.type))
        else
          dynamic
        end

      {column, "lte." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) <= type(^value, ^column.type))
        else
          dynamic
        end

      {column, "neq." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic([t], ^dynamic and field(t, ^column.aname) != type(^value, ^column.type))
        else
          dynamic
        end

      {column, "like." <> value}, dynamic ->
        if column = find_column(columns, column) do
          pattern = String.replace(value, "*", "%")
          dynamic([t], ^dynamic and like(field(t, ^column.aname), ^pattern))
        else
          dynamic
        end

      {column, "ilike." <> value}, dynamic ->
        if column = find_column(columns, column) do
          pattern = String.replace(value, "*", "%")
          dynamic([t], ^dynamic and ilike(field(t, ^column.aname), ^pattern))
        else
          dynamic
        end

      # {column, "in." <> value}, dynamic ->
      #   if column = find_column(columns, column) do
      #     # list = parse_list(value)
      #     # TODO quoted strings
      #     list = value |> String.trim(["(", ")"]) |> String.split(",")
      #     # TODO type(list, {:array, column.type})?
      #     dynamic([t], ^dynamic and field(t, ^column.aname) in ^list)
      #   else
      #     dynamic
      #   end

      {column, "is." <> value}, dynamic ->
        if column = find_column(columns, column) do
          dynamic(
            [t],
            ^dynamic and fragment("? is ?", field(t, ^column.aname), type(^value, ^column.type))
          )
        else
          dynamic
        end

      # TODO more operators
      # in, or, and, not, nested or, and

      {_, _}, dynamic ->
        dynamic
    end)
  end

  defp filter_order_by(nil, _columns), do: []

  defp filter_order_by(order_by, columns) do
    order_by
    |> String.split(",")
    |> Enum.flat_map(fn rule ->
      case String.split(rule, ".", parts: 2) do
        [column] ->
          if column = find_column(columns, column) do
            [{:asc, column.aname}]
          else
            []
          end

        [column, direction] ->
          column = find_column(columns, column)
          direction = order_by_direction(direction)

          if column && direction do
            [{direction, column.aname}]
          else
            []
          end
      end
    end)
  end

  defp find_column(columns, column) do
    Enum.find(columns, fn c -> c.sname == column end)
  end

  defp order_by_direction("asc"), do: :asc
  defp order_by_direction("desc"), do: :desc
  defp order_by_direction("nullsfirst"), do: :asc_nulls_first
  defp order_by_direction("nullslast"), do: :asc_nulls_last
  defp order_by_direction("desc.nullsfirst"), do: :desc_nulls_first
  defp order_by_direction("desc.nullslast"), do: :desc_nulls_last
  defp order_by_direction("asc.nullsfirst"), do: :asc_nulls_first
  defp order_by_direction("asc.nullslast"), do: :asc_nulls_last

  # TODO to json?
  defp selected(nil, columns), do: columns

  defp selected(selected, known_columns) do
    selected
    |> String.split(",", trim: true)
    |> Enum.reduce([], fn column, acc ->
      if column = Enum.find(known_columns, fn known -> known.sname == column end) do
        [column | acc]
      else
        acc
      end
    end)
  end
end
