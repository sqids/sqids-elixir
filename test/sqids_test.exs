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
      assert Sqids.new(alphabet: "ë1092") === {:error, {:alphabet_contains_multibyte_graphemes, ["ë"]}}
    end

    test "repeating characters" do
      assert Sqids.new(alphabet: "aabcdefg") === {:error, {:alphabet_contains_repeated_graphemes, ["a"]}}
    end

    test "too short of an alphabet" do
      assert Sqids.new(alphabet: "ab") === {:error, {:alphabet_is_too_small, min_length: 3, alphabet: "ab"}}
    end

    defp assert_encode_and_back(ctx, numbers) do
      assert Sqids.decode!(ctx, Sqids.encode!(ctx, numbers)) === numbers
    end
  end

  defmodule Encoding do
    @moduledoc false
    use ExUnit.Case, async: true

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1

    test "simple" do
      {:ok, ctx} = Sqids.new()

      numbers = [1, 2, 3]
      id = "86Rf07"

      assert Sqids.encode!(ctx, numbers) === id
      assert Sqids.decode!(ctx, id) === numbers
    end

    test "different inputs" do
      {:ok, ctx} = Sqids.new()

      numbers = [0, 0, 0, 1, 2, 3, 100, 1_000, 100_000, 1_000_000, @js_max_safe_integer]
      assert_encode_and_back(ctx, numbers)
    end

    test "incremental numbers" do
      {:ok, ctx} = Sqids.new()

      ids = %{
        "bM" => [0],
        "Uk" => [1],
        "gb" => [2],
        "Ef" => [3],
        "Vq" => [4],
        "uw" => [5],
        "OI" => [6],
        "AX" => [7],
        "p6" => [8],
        "nJ" => [9]
      }

      Enum.each(ids, fn {id, numbers} ->
        assert Sqids.encode!(ctx, numbers) === id
        assert Sqids.decode!(ctx, id) === numbers
      end)
    end

    test "incremental numbers, same index 0" do
      {:ok, ctx} = Sqids.new()

      ids = %{
        "SvIz" => [0, 0],
        "n3qa" => [0, 1],
        "tryF" => [0, 2],
        "eg6q" => [0, 3],
        "rSCF" => [0, 4],
        "sR8x" => [0, 5],
        "uY2M" => [0, 6],
        "74dI" => [0, 7],
        "30WX" => [0, 8],
        "moxr" => [0, 9]
      }

      Enum.each(ids, fn {id, numbers} ->
        assert Sqids.encode!(ctx, numbers) === id
        assert Sqids.decode!(ctx, id) === numbers
      end)
    end

    test "incremental numbers, same index 1" do
      {:ok, ctx} = Sqids.new()

      ids = %{
        "SvIz" => [0, 0],
        "nWqP" => [1, 0],
        "tSyw" => [2, 0],
        "eX68" => [3, 0],
        "rxCY" => [4, 0],
        "sV8a" => [5, 0],
        "uf2K" => [6, 0],
        "7Cdk" => [7, 0],
        "3aWP" => [8, 0],
        "m2xn" => [9, 0]
      }

      Enum.each(ids, fn {id, numbers} ->
        assert Sqids.encode!(ctx, numbers) === id
        assert Sqids.decode!(ctx, id) === numbers
      end)
    end

    test "multi input" do
      {:ok, ctx} = Sqids.new()

      numbers = [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63,
        64,
        65,
        66,
        67,
        68,
        69,
        70,
        71,
        72,
        73,
        74,
        75,
        76,
        77,
        78,
        79,
        80,
        81,
        82,
        83,
        84,
        85,
        86,
        87,
        88,
        89,
        90,
        91,
        92,
        93,
        94,
        95,
        96,
        97,
        98,
        99
      ]

      assert_encode_and_back(ctx, numbers)
    end

    test "encoding no numbers" do
      {:ok, ctx} = Sqids.new()

      assert Sqids.encode!(ctx, []) === ""
    end

    test "decoding empty string" do
      {:ok, ctx} = Sqids.new()

      assert Sqids.decode!(ctx, "") === []
    end

    test "decoding an id with an invalid character" do
      {:ok, ctx} = Sqids.new()

      assert Sqids.decode!(ctx, "*") === []
    end

    test "encoding out of range numbers" do
      # TODO should this implementation limit numbers, given Erlang integers are bigints?
    end

    defp assert_encode_and_back(ctx, numbers) do
      assert Sqids.decode!(ctx, Sqids.encode!(ctx, numbers)) === numbers
    end
  end
end
