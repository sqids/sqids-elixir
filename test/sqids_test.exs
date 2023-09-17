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
    assert Sqids.encode!(ctx, [40, 90]) == "RYer3"

    1..100
    |> Enum.each(
      fn _iteration ->
        nr_of_numbers = :rand.uniform(5)
        numbers = for _ <- 1..nr_of_numbers, do: :rand.uniform(10000) - 1
        id = Sqids.encode!(ctx, numbers)
        assert Sqids.decode!(ctx, id) == numbers
      end)
  end
end
