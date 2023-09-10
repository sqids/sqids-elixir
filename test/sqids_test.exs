defmodule SqidsTest do
  use ExUnit.Case

  doctest Sqids

  test "greets the world" do
    assert Sqids.hello() == :world
  end
end
