defmodule SqidsTest do
  # doctest Sqids

  defmodule Alphabet do
    @moduledoc false
    use ExUnit.Case, async: true

    test "simple" do
      {:ok, sqids} = Sqids.new(alphabet: "0123456789abcdef")

      numbers = [1, 2, 3]
      id = "489158"

      assert Sqids.encode!(sqids, numbers) === id
      assert Sqids.decode!(sqids, id) === numbers
    end

    test "short alphabet" do
      {:ok, sqids} = Sqids.new(alphabet: "abc")

      assert_encode_and_back(sqids, [1, 2, 3])
    end

    test "long alphabet" do
      {:ok, sqids} =
        Sqids.new(
          alphabet: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_+|{}[];:'\"/?.>,<`~"
        )

      assert_encode_and_back(sqids, [1, 2, 3])
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

    defp assert_encode_and_back(sqids, numbers) do
      assert Sqids.decode!(sqids, Sqids.encode!(sqids, numbers)) === numbers
    end
  end

  defmodule Blocklist do
    @moduledoc false
    use ExUnit.Case, async: true

    test "if no custom blocklist param, use the default blocklist" do
      {:ok, sqids} = Sqids.new()

      assert Sqids.decode!(sqids, "aho1e") === [4_572_721]
      assert Sqids.encode!(sqids, [4_572_721]) === "JExTR"
    end

    test "if an empty blocklist param passed, don't use any blocklist" do
      {:ok, sqids} = Sqids.new(blocklist: [])

      assert Sqids.decode!(sqids, "aho1e") === [4_572_721]
      assert Sqids.encode!(sqids, [4_572_721]) === "aho1e"
    end

    test "if a non-empty blocklist param passed, use only that" do
      {:ok, sqids} =
        Sqids.new(
          blocklist: [
            # originally encoded [100_000]
            "ArUO"
          ]
        )

      # make sure we don't use the default blocklist
      assert Sqids.decode!(sqids, "aho1e") === [4_572_721]
      assert Sqids.encode!(sqids, [4_572_721]) === "aho1e"

      # make sure we are using the passed blocklist
      assert Sqids.decode!(sqids, "ArUO") === [100_000]
      assert Sqids.encode!(sqids, [100_000]) === "QyG4"
      assert Sqids.decode!(sqids, "QyG4") === [100_000]
    end

    test "blocklist" do
      {:ok, sqids} =
        Sqids.new(
          blocklist: [
            # normal result of 1st encoding, let"s block that word on purpose
            "JSwXFaosAN",
            # result of 2nd encoding
            "OCjV9JK64o",
            # result of 3rd encoding is `4rBHfOiqd3`, let"s block a substring
            "rBHf",
            # result of 4th encoding is `dyhgw479SM`, let"s block the postfix
            "79SM",
            # result of 4th encoding is `7tE6jdAHLe`, let"s block the prefix
            "7tE6"
          ]
        )

      assert Sqids.encode!(sqids, [1_000_000, 2_000_000]) === "1aYeB7bRUt"
      assert Sqids.decode!(sqids, "1aYeB7bRUt") === [1_000_000, 2_000_000]
    end

    test "decoding blocklist words should still work" do
      {:ok, sqids} = Sqids.new(blocklist: ["86Rf07", "se8ojk", "ARsz1p", "Q8AI49", "5sQRZO"])

      assert Sqids.decode!(sqids, "86Rf07") === [1, 2, 3]
      assert Sqids.decode!(sqids, "se8ojk") === [1, 2, 3]
      assert Sqids.decode!(sqids, "ARsz1p") === [1, 2, 3]
      assert Sqids.decode!(sqids, "Q8AI49") === [1, 2, 3]
      assert Sqids.decode!(sqids, "5sQRZO") === [1, 2, 3]
    end

    test "match against a a short blocklist word" do
      {:ok, sqids} = Sqids.new(blocklist: ["pnd"])

      assert Sqids.decode!(sqids, Sqids.encode!(sqids, [1_000])) === [1_000]
    end

    test "blocklist filtering in new" do
      {:ok, sqids} =
        Sqids.new(
          alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          # lowercase blocklist in only-uppercase alphabet
          blocklist: ["sxnzkl"]
        )

      id = Sqids.encode!(sqids, [1, 2, 3])
      numbers = Sqids.decode!(sqids, id)

      # without blocklist, would've been "SXNZKL"
      assert id === "IBSHOZ"
      assert numbers === [1, 2, 3]
    end

    test "max encoding attempts" do
      alphabet = "abc"
      min_length = 3
      blocklist = ["cab", "abc", "bca"]

      assert String.length(alphabet) === min_length
      assert length(blocklist) === min_length
      {:ok, sqids} = Sqids.new(alphabet: alphabet, min_length: min_length, blocklist: blocklist)

      assert Sqids.encode(sqids, [0]) === {:error, {:reached_max_attempts_to_regenerate_the_id, 3}}
    end
  end

  defmodule Encoding do
    @moduledoc false
    use ExUnit.Case, async: true

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1
    @max_uint128 Bitwise.<<<(1, 128) - 1
    @max_uint256 Bitwise.<<<(1, 256) - 1
    @max_uint1024 Bitwise.<<<(1, 1024) - 1

    test "simple" do
      {:ok, sqids} = Sqids.new()

      numbers = [1, 2, 3]
      id = "86Rf07"

      assert Sqids.encode!(sqids, numbers) === id
      assert Sqids.decode!(sqids, id) === numbers
    end

    test "different inputs" do
      {:ok, sqids} = Sqids.new()

      numbers = [0, 0, 0, 1, 2, 3, 100, 1_000, 100_000, 1_000_000, @js_max_safe_integer]
      assert_encode_and_back(sqids, numbers)
    end

    test "incremental numbers" do
      {:ok, sqids} = Sqids.new()

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
        assert Sqids.encode!(sqids, numbers) === id
        assert Sqids.decode!(sqids, id) === numbers
      end)
    end

    test "incremental numbers, same index 0" do
      {:ok, sqids} = Sqids.new()

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
        assert Sqids.encode!(sqids, numbers) === id
        assert Sqids.decode!(sqids, id) === numbers
      end)
    end

    test "incremental numbers, same index 1" do
      {:ok, sqids} = Sqids.new()

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
        assert Sqids.encode!(sqids, numbers) === id
        assert Sqids.decode!(sqids, id) === numbers
      end)
    end

    test "multi input" do
      {:ok, sqids} = Sqids.new()

      numbers = Enum.to_list(0..99)

      assert_encode_and_back(sqids, numbers)
    end

    test "encoding no numbers" do
      {:ok, sqids} = Sqids.new()

      assert Sqids.encode!(sqids, []) === ""
    end

    test "decoding empty string" do
      {:ok, sqids} = Sqids.new()

      assert Sqids.decode!(sqids, "") === []
    end

    test "decoding an id with an invalid character" do
      {:ok, sqids} = Sqids.new()

      assert Sqids.decode!(sqids, "*") === []
    end

    test "encoding bigints" do
      {:ok, sqids} = Sqids.new()

      assert_encode_and_back(sqids, [@max_uint128])
      assert_encode_and_back(sqids, [@max_uint256])
      assert_encode_and_back(sqids, [@max_uint1024])
      assert_encode_and_back(sqids, [@max_uint256, @max_uint128, @max_uint1024])
      assert_encode_and_back(sqids, [@max_uint1024, @max_uint256, @max_uint1024])
    end

    defp assert_encode_and_back(sqids, numbers) do
      assert Sqids.decode!(sqids, Sqids.encode!(sqids, numbers)) === numbers
    end
  end

  defmodule MinLength do
    @moduledoc false
    use ExUnit.Case, async: true

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1

    test "simple" do
      {:ok, sqids} = Sqids.new(min_length: String.length(Sqids.default_alphabet()))

      numbers = [1, 2, 3]
      id = "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM"

      assert Sqids.encode!(sqids, numbers) === id
      assert Sqids.decode!(sqids, id) === numbers
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
          {:ok, sqids} = Sqids.new(min_length: min_length)

          assert Sqids.encode!(sqids, numbers) === id
          assert sqids |> Sqids.encode!(numbers) |> String.length() >= min_length
          assert Sqids.decode!(sqids, id) === numbers
        end
      )
    end

    test "incremental numbers" do
      {:ok, sqids} = Sqids.new(min_length: String.length(Sqids.default_alphabet()))

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
          assert Sqids.encode!(sqids, numbers) === id
          assert Sqids.decode!(sqids, id) === numbers
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
        {:ok, sqids} = Sqids.new(min_length: min_length)

        id = Sqids.encode!(sqids, number)
        assert String.length(id) >= min_length
        assert Sqids.decode!(sqids, id) === number
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
