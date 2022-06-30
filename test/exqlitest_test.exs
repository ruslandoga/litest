defmodule ExqlitestTest do
  use ExUnit.Case
  doctest Exqlitest

  test "greets the world" do
    assert Exqlitest.hello() == :world
  end
end
