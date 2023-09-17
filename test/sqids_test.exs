defmodule SqidsTest do
  use ExUnit.Case

  doctest Sqids

  test "TEMP: no regressions while iterating" do
    # Temporary test to quickly check for regressions while iterating
    {:ok, ctx} = Sqids.new()
    assert Sqids.encode!(ctx, [1]) == "Uk"
    assert Sqids.encode!(ctx, [12]) == "vE"
    assert Sqids.encode!(ctx, [123]) == "UKk"
    assert Sqids.encode!(ctx, [1234]) == "A4W"
    assert Sqids.encode!(ctx, [12_345]) == "A6da"
  end
end
