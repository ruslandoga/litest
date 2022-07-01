defmodule E.Repo.Migrations.AddPeople do
  use Ecto.Migration

  def change do
    create table(:people) do
      add :name, :string
      add :age, :integer
      add :student, :boolean
    end
  end
end
