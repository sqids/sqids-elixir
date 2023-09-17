defmodule SqidsTest do
  # doctest Sqids

  defmodule Alphabet do
    @moduledoc false
    use ExUnit.Case, async: true

    test "simple" do
      {:ok, ctx} = Sqids.new(alphabet: "0123456789abcdef")

      numbers = [1, 2, 3]
      id = "489158"

      assert Sqids.encode!(ctx, numbers) === id
      assert Sqids.decode!(ctx, id) === numbers
    end

    test "short alphabet" do
      {:ok, ctx} = Sqids.new(alphabet: "abc")

      assert_encode_and_back(ctx, [1, 2, 3])
    end

    test "long alphabet" do
      {:ok, ctx} =
        Sqids.new(
          alphabet: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_+|{}[];:'\"/?.>,<`~"
        )

      assert_encode_and_back(ctx, [1, 2, 3])
    end

    test "multibyte characters" do
      assert Sqids.new(alphabet: "ë1092") == {:error, {:alphabet_contains_multibyte_graphemes, ["ë"]}}
    end

    test "repeating characters" do
      assert Sqids.new(alphabet: "aabcdefg") == {:error, {:alphabet_contains_repeated_graphemes, ["a"]}}
    end

    test "too short of an alphabet" do
      assert Sqids.new(alphabet: "ab") == {:error, {:alphabet_is_too_small, min_length: 3, alphabet: "ab"}}
    end

    defp assert_encode_and_back(ctx, numbers) do
      assert Sqids.decode!(ctx, Sqids.encode!(ctx, numbers)) == numbers
    end
  end
end
