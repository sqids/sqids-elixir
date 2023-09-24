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

  defmodule Blocklist do
    @moduledoc false
    use ExUnit.Case, async: true

    # TODO implement blocklist properly
  end

  defmodule Encoding do
    @moduledoc false
    use ExUnit.Case, async: true

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1
    @max_uint128 Bitwise.<<<(1, 128) - 1
    @max_uint256 Bitwise.<<<(1, 256) - 1
    @max_uint1024 Bitwise.<<<(1, 1024) - 1

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

      numbers = Enum.to_list(0..99)

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

    test "encoding bigints" do
      {:ok, ctx} = Sqids.new()

      assert_encode_and_back(ctx, [@max_uint128])
      assert_encode_and_back(ctx, [@max_uint256])
      assert_encode_and_back(ctx, [@max_uint1024])
      assert_encode_and_back(ctx, [@max_uint256, @max_uint128, @max_uint1024])
      assert_encode_and_back(ctx, [@max_uint1024, @max_uint256, @max_uint1024])
    end

    defp assert_encode_and_back(ctx, numbers) do
      assert Sqids.decode!(ctx, Sqids.encode!(ctx, numbers)) === numbers
    end
  end

  defmodule MinLength do
    @moduledoc false
    use ExUnit.Case, async: true

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1

    test "simple" do
      {:ok, ctx} = Sqids.new(min_length: String.length(Sqids.default_alphabet()))

      numbers = [1, 2, 3]
      id = "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM"

      assert Sqids.encode!(ctx, numbers) === id
      assert Sqids.decode!(ctx, id) === numbers
    end

    test "incremental" do
      numbers = [1, 2, 3]
      default_alphabet_length = String.length(Sqids.default_alphabet())

      Enum.each(
        %{
          6 => "86Rf07",
          7 => "86Rf07x",
          8 => "86Rf07xd",
          9 => "86Rf07xd4",
          10 => "86Rf07xd4z",
          11 => "86Rf07xd4zB",
          12 => "86Rf07xd4zBm",
          13 => "86Rf07xd4zBmi",
          default_alphabet_length => "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM",
          (default_alphabet_length + 1) => "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMy",
          (default_alphabet_length + 2) => "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMyf",
          (default_alphabet_length + 3) => "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMyf1"
        },
        fn {min_length, id} ->
          {:ok, ctx} = Sqids.new(min_length: min_length)

          assert Sqids.encode!(ctx, numbers) === id
          assert ctx |> Sqids.encode!(numbers) |> String.length() >= min_length
          assert Sqids.decode!(ctx, id) === numbers
        end
      )
    end

    test "incremental numbers" do
      {:ok, ctx} = Sqids.new(min_length: String.length(Sqids.default_alphabet()))

      Enum.each(
        %{
          "SvIzsqYMyQwI3GWgJAe17URxX8V924Co0DaTZLtFjHriEn5bPhcSkfmvOslpBu" => [0, 0],
          "n3qafPOLKdfHpuNw3M61r95svbeJGk7aAEgYn4WlSjXURmF8IDqZBy0CT2VxQc" => [0, 1],
          "tryFJbWcFMiYPg8sASm51uIV93GXTnvRzyfLleh06CpodJD42B7OraKtkQNxUZ" => [0, 2],
          "eg6ql0A3XmvPoCzMlB6DraNGcWSIy5VR8iYup2Qk4tjZFKe1hbwfgHdUTsnLqE" => [0, 3],
          "rSCFlp0rB2inEljaRdxKt7FkIbODSf8wYgTsZM1HL9JzN35cyoqueUvVWCm4hX" => [0, 4],
          "sR8xjC8WQkOwo74PnglH1YFdTI0eaf56RGVSitzbjuZ3shNUXBrqLxEJyAmKv2" => [0, 5],
          "uY2MYFqCLpgx5XQcjdtZK286AwWV7IBGEfuS9yTmbJvkzoUPeYRHr4iDs3naN0" => [0, 6],
          "74dID7X28VLQhBlnGmjZrec5wTA1fqpWtK4YkaoEIM9SRNiC3gUJH0OFvsPDdy" => [0, 7],
          "30WXpesPhgKiEI5RHTY7xbB1GnytJvXOl2p0AcUjdF6waZDo9Qk8VLzMuWrqCS" => [0, 8],
          "moxr3HqLAK0GsTND6jowfZz3SUx7cQ8aC54Pl1RbIvFXmEJuBMYVeW9yrdOtin" => [0, 9]
        },
        fn {id, numbers} ->
          assert Sqids.encode!(ctx, numbers) === id
          assert Sqids.decode!(ctx, id) === numbers
        end
      )
    end

    test "min lengths" do
      min_lengths = [0, 1, 5, 10, String.length(Sqids.default_alphabet())]

      numbers = [
        [0],
        [0, 0, 0, 0, 0],
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        [100, 200, 300],
        [1_000, 2_000, 3_000],
        [1_000_000],
        [@js_max_safe_integer]
      ]

      for_result = for(min_length <- min_lengths, number <- numbers, do: {min_length, number})

      Enum.each(for_result, fn {min_length, number} ->
        {:ok, ctx} = Sqids.new(min_length: min_length)

        id = Sqids.encode!(ctx, number)
        assert String.length(id) >= min_length
        assert Sqids.decode!(ctx, id) === number
      end)
    end

    # for those langs that don't support `u8`
    test "out-of-range invalid min length" do
      assert Sqids.new(min_length: -1) == {:error, {:min_length_not_an_integer_in_range, -1, range: 0..255}}
      assert Sqids.new(min_length: 256) == {:error, {:min_length_not_an_integer_in_range, 256, range: 0..255}}
      assert Sqids.new(min_length: "1") == {:error, {:min_length_not_an_integer_in_range, "1", range: 0..255}}
    end
  end
end
