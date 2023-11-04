# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule SqidsTest do
  # doctest Sqids

  require Bitwise

  ## Shared between test cases

  defmodule Shared do
    @moduledoc false
    defmodule UsingModule do
      @moduledoc false
      use Sqids

      @impl true
      def child_spec, do: child_spec([])
    end

    def new_sqids(_access_type, opts \\ [])

    def new_sqids(:"Direct API", opts) do
      case Sqids.new(opts) do
        {:ok, sqids} ->
          {:ok, {:direct_api, sqids}}

        {:error, _} = error ->
          error
      end
    end

    def new_sqids(:"Direct API!", opts) do
      sqids = Sqids.new!(opts)
      {:ok, {:direct_api, sqids}}
    end

    def new_sqids(:"Using module", opts) do
      module_name = String.to_atom("#{__MODULE__}.UsingModule.#{:rand.uniform(Bitwise.<<<(1, 64))}")

      module_content =
        quote do
          use Sqids

          @impl true
          def child_spec, do: child_spec([])
        end

      Module.create(module_name, module_content, Macro.Env.location(__ENV__))

      case module_name.start_link(opts) do
        {:ok, pid} ->
          {:ok, {:using_module, module_name, pid}}

        {:error, _} = error ->
          error
      end
    end

    def encode!(instance, numbers) do
      call_instance_fun(instance, :encode!, [numbers])
    end

    def encode(instance, numbers) do
      call_instance_fun(instance, :encode, [numbers])
    end

    def decode!(instance, id) do
      call_instance_fun(instance, :decode!, [id])
    end

    def assert_encode_and_back(sqids, numbers) do
      import ExUnit.Assertions

      assert decode!(sqids, encode!(sqids, numbers)) === numbers
    end

    defp call_instance_fun(instance, name, args) do
      case instance do
        {:direct_api, sqids} ->
          apply(Sqids, name, [sqids | args])

        {:using_module, module_name, _pid} ->
          apply(module_name, name, args)
      end
    end
  end

  ## Test cases

  defmodule Alphabet do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: simple" do
        {:ok, instance} = new_sqids(unquote(access_type), alphabet: "0123456789abcdef")

        numbers = [1, 2, 3]
        id = "489158"

        assert encode!(instance, numbers) === id
        assert decode!(instance, id) === numbers
      end

      test "#{access_type}: short alphabet" do
        {:ok, instance} = new_sqids(unquote(access_type), alphabet: "abc")

        assert_encode_and_back(instance, [1, 2, 3])
      end

      test "#{access_type}: long alphabet" do
        {:ok, instance} =
          new_sqids(unquote(access_type),
            alphabet: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_+|{}[];:'\"/?.>,<`~"
          )

        assert_encode_and_back(instance, [1, 2, 3])
      end

      test "#{access_type}: multibyte characters" do
        assert new_sqids(unquote(access_type), alphabet: "ë1092") ===
                 {:error, {:alphabet_contains_multibyte_graphemes, ["ë"]}}
      end

      test "#{access_type}: repeating characters" do
        assert new_sqids(unquote(access_type), alphabet: "aabcdefg") ===
                 {:error, {:alphabet_contains_repeated_graphemes, ["a"]}}
      end

      test "#{access_type}: too short of an alphabet" do
        assert new_sqids(unquote(access_type), alphabet: "ab") ===
                 {:error, {:alphabet_is_too_small, min_length: 3, alphabet: "ab"}}
      end
    end
  end

  defmodule Blocklist do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: if no custom blocklist param, use the default blocklist" do
        {:ok, instance} = new_sqids(unquote(access_type))

        assert decode!(instance, "aho1e") === [4_572_721]
        assert encode!(instance, [4_572_721]) === "JExTR"
      end

      test "#{access_type}: if an empty blocklist param passed, don't use any blocklist" do
        {:ok, instance} = new_sqids(unquote(access_type), blocklist: [])

        assert decode!(instance, "aho1e") === [4_572_721]
        assert encode!(instance, [4_572_721]) === "aho1e"
      end

      test "#{access_type}: if a non-empty blocklist param passed, use only that" do
        {:ok, instance} =
          new_sqids(unquote(access_type),
            blocklist: [
              # originally encoded [100_000]
              "ArUO"
            ]
          )

        # make sure we don't use the default blocklist
        assert decode!(instance, "aho1e") === [4_572_721]
        assert encode!(instance, [4_572_721]) === "aho1e"

        # make sure we are using the passed blocklist
        assert decode!(instance, "ArUO") === [100_000]
        assert encode!(instance, [100_000]) === "QyG4"
        assert decode!(instance, "QyG4") === [100_000]
      end

      test "#{access_type}: blocklist" do
        {:ok, instance} =
          new_sqids(unquote(access_type),
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

        assert encode!(instance, [1_000_000, 2_000_000]) === "1aYeB7bRUt"
        assert decode!(instance, "1aYeB7bRUt") === [1_000_000, 2_000_000]
      end

      test "#{access_type}: decoding blocklist words should still work" do
        {:ok, instance} = new_sqids(unquote(access_type), blocklist: ["86Rf07", "se8ojk", "ARsz1p", "Q8AI49", "5sQRZO"])

        assert decode!(instance, "86Rf07") === [1, 2, 3]
        assert decode!(instance, "se8ojk") === [1, 2, 3]
        assert decode!(instance, "ARsz1p") === [1, 2, 3]
        assert decode!(instance, "Q8AI49") === [1, 2, 3]
        assert decode!(instance, "5sQRZO") === [1, 2, 3]
      end

      test "#{access_type}: match against a a short blocklist word" do
        {:ok, instance} = new_sqids(unquote(access_type), blocklist: ["pnd"])

        assert decode!(instance, encode!(instance, [1_000])) === [1_000]
      end

      test "#{access_type}: blocklist filtering in new" do
        {:ok, instance} =
          new_sqids(unquote(access_type),
            alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            # lowercase blocklist in only-uppercase alphabet
            blocklist: ["sxnzkl"]
          )

        id = encode!(instance, [1, 2, 3])
        numbers = decode!(instance, id)

        # without blocklist, would've been "SXNZKL"
        assert id === "IBSHOZ"
        assert numbers === [1, 2, 3]
      end

      test "#{access_type}: max encoding attempts" do
        alphabet = "abc"
        min_length = 3
        blocklist = ["cab", "abc", "bca"]

        assert String.length(alphabet) === min_length
        assert length(blocklist) === min_length

        {:ok, instance} =
          new_sqids(unquote(access_type), alphabet: alphabet, min_length: min_length, blocklist: blocklist)

        input = [0]
        assert encode(instance, input) === {:error, {:all_id_generation_attempts_were_censored, 3}}
        assert_raise RuntimeError, "All id generation attempts were censored: 3", fn -> encode!(instance, input) end
      end
    end
  end

  defmodule Encoding do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1
    @max_uint128 Bitwise.<<<(1, 128) - 1
    @max_uint256 Bitwise.<<<(1, 256) - 1
    @max_uint1024 Bitwise.<<<(1, 1024) - 1

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: simple" do
        {:ok, instance} = new_sqids(unquote(access_type))

        numbers = [1, 2, 3]
        id = "86Rf07"

        assert encode!(instance, numbers) === id
        assert decode!(instance, id) === numbers
      end

      test "#{access_type}: different inputs" do
        {:ok, instance} = new_sqids(unquote(access_type))

        numbers = [0, 0, 0, 1, 2, 3, 100, 1_000, 100_000, 1_000_000, @js_max_safe_integer]
        assert_encode_and_back(instance, numbers)
      end

      test "#{access_type}: incremental numbers" do
        {:ok, instance} = new_sqids(unquote(access_type))

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
          assert encode!(instance, numbers) === id
          assert decode!(instance, id) === numbers
        end)
      end

      test "#{access_type}: incremental numbers, same index 0" do
        {:ok, instance} = new_sqids(unquote(access_type))

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
          assert encode!(instance, numbers) === id
          assert decode!(instance, id) === numbers
        end)
      end

      test "#{access_type}: incremental numbers, same index 1" do
        {:ok, instance} = new_sqids(unquote(access_type))

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
          assert encode!(instance, numbers) === id
          assert decode!(instance, id) === numbers
        end)
      end

      test "#{access_type}: multi input" do
        {:ok, instance} = new_sqids(unquote(access_type))

        numbers = Enum.to_list(0..99)

        assert_encode_and_back(instance, numbers)
      end

      test "#{access_type}: encoding no numbers" do
        {:ok, instance} = new_sqids(unquote(access_type))

        assert encode!(instance, []) === ""
      end

      test "#{access_type}: decoding empty string" do
        {:ok, instance} = new_sqids(unquote(access_type))

        assert decode!(instance, "") === []
      end

      test "#{access_type}: decoding an id with an invalid character" do
        {:ok, instance} = new_sqids(unquote(access_type))

        assert decode!(instance, "*") === []
      end

      test "#{access_type}: encoding bigints" do
        {:ok, instance} = new_sqids(unquote(access_type))

        assert_encode_and_back(instance, [@max_uint128])
        assert_encode_and_back(instance, [@max_uint256])
        assert_encode_and_back(instance, [@max_uint1024])
        assert_encode_and_back(instance, [@max_uint256, @max_uint128, @max_uint1024])
        assert_encode_and_back(instance, [@max_uint1024, @max_uint256, @max_uint1024])
      end
    end
  end

  defmodule MinLength do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    @js_max_safe_integer Bitwise.<<<(1, 52) - 1

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: simple" do
        {:ok, instance} = new_sqids(unquote(access_type), min_length: String.length(Sqids.default_alphabet()))

        numbers = [1, 2, 3]
        id = "86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM"

        assert encode!(instance, numbers) === id
        assert decode!(instance, id) === numbers
      end

      test "#{access_type}: incremental" do
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
            {:ok, instance} = new_sqids(unquote(access_type), min_length: min_length)

            assert encode!(instance, numbers) === id
            assert instance |> encode!(numbers) |> String.length() >= min_length
            assert decode!(instance, id) === numbers
          end
        )
      end

      test "#{access_type}: incremental numbers" do
        {:ok, instance} = new_sqids(unquote(access_type), min_length: String.length(Sqids.default_alphabet()))

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
            assert encode!(instance, numbers) === id
            assert decode!(instance, id) === numbers
          end
        )
      end

      test "#{access_type}: min lengths" do
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
          {:ok, instance} = new_sqids(unquote(access_type), min_length: min_length)

          id = encode!(instance, number)
          assert String.length(id) >= min_length
          assert decode!(instance, id) === number
        end)
      end

      # for those langs that don't support `u8`
      test "#{access_type}: out-of-range invalid min length" do
        assert_raise ArgumentError, "Min length is not an integer in range: [value: -1, range: 0..255]", fn ->
          new_sqids(unquote(access_type), min_length: -1)
        end

        assert_raise ArgumentError, "Min length is not an integer in range: [value: 256, range: 0..255]", fn ->
          new_sqids(unquote(access_type), min_length: 256)
        end

        assert_raise ArgumentError, "Min length is not an integer in range: [value: \"1\", range: 0..255]", fn ->
          new_sqids(unquote(access_type), min_length: "1")
        end
      end
    end
  end

  defmodule AdditionalInstantiationScenarios do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    test "new!/0: it works" do
      sqids = Sqids.new!()

      numbers = [1, 2, 3]
      id = "86Rf07"

      assert Sqids.encode(sqids, numbers) === {:ok, id}
      assert Sqids.decode!(sqids, id) === numbers
    end

    test "new!/1: it works with valid opts" do
      {:ok, instance} = new_sqids(:"Direct API!")

      numbers = [1, 2, 3]
      id = "86Rf07"

      assert encode!(instance, numbers) === id
      assert decode!(instance, id) === numbers
    end

    test "new!/1: errors raised" do
      assert_raise ArgumentError, "Alphabet contains multibyte graphemes: [\"ë\"]", fn ->
        new_sqids(:"Direct API!", alphabet: "ë1092")
      end

      assert_raise ArgumentError, "Alphabet contains repeated graphemes: [\"a\"]", fn ->
        new_sqids(:"Direct API!", alphabet: "aabcdefg")
      end

      assert_raise ArgumentError, "Alphabet is too small: [min_length: 3, alphabet: \"ab\"]", fn ->
        new_sqids(:"Direct API!", alphabet: "ab")
      end
    end

    for access_type <- [:"Direct API", :"Direct API!", :"Using module"] do
      test "#{access_type}: new/1: options is not a proper list" do
        at = unquote(access_type)
        assert_raise ArgumentError, "Opts not a proper list: :not_a_list", fn -> new_sqids(at, :not_a_list) end

        assert_raise ArgumentError, "Opts not a proper list: [:improper | :list]", fn ->
          new_sqids(at, [:improper | :list])
        end
      end

      test "#{access_type}: new/2: alphabet is not an UTF-8 string" do
        at = unquote(access_type)

        input = [3]
        assert_raise ArgumentError, "Alphabet is not an utf8 string: [3]", fn -> new_sqids(at, alphabet: input) end

        input = ~c"abcdf"

        assert_raise ArgumentError, ~r/Alphabet is not an utf8 string: .+/, fn ->
          new_sqids(at, alphabet: input)
        end

        input = <<128>>
        assert_raise ArgumentError, "Alphabet is not an utf8 string: <<128>>", fn -> new_sqids(at, alphabet: input) end
      end

      test "#{access_type}: new/1: blocklist is not enumerable" do
        at = unquote(access_type)

        input = {"word"}
        assert_raise ArgumentError, "Blocklist is not enumerable: {\"word\"}", fn -> new_sqids(at, blocklist: input) end

        input = 42.456
        assert_raise ArgumentError, "Blocklist is not enumerable: 42.456", fn -> new_sqids(at, blocklist: input) end

        input = "555"
        assert_raise ArgumentError, "Blocklist is not enumerable: \"555\"", fn -> new_sqids(at, blocklist: input) end
      end

      test "#{access_type}: new/1: some words in blocklist are not UTF-8 strings " do
        at = unquote(access_type)

        input = ["aaaa", -44.3, "ok", 5, "go", <<128>>, <<129>>, "done"]

        assert_raise ArgumentError, "Some words in blocklist are not utf8 strings: [-44.3, 5, <<128>>, <<129>>]", fn ->
          new_sqids(at, blocklist: input)
        end
      end
    end

    test "Blocklist: short words are not blocked" do
      alphabet_str = "abc"
      {:ok, blocklist} = Sqids.Blocklist.new(["abc"], _min_word_length = 4, alphabet_str)
      refute Sqids.Blocklist.is_blocked_id(blocklist, "abc")
    end

    test "Stopped agent" do
      assert_raise RuntimeError, ~r/Sqids shared state not found/, fn -> Sqids.Agent.get(RandomModule354343) end
    end
  end

  defmodule AdditionalEncodingScenarios do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    test "encode/2: invalid sqids" do
      sqids = :no
      assert_raise ArgumentError, "argument error: :no", fn -> Sqids.encode(sqids, [33]) end

      sqids = %{a: 55}
      assert_raise ArgumentError, "argument error: %{a: 55}", fn -> Sqids.encode(sqids, [33]) end

      sqids = %{__struct__: No}
      assert_raise ArgumentError, "argument error: %{__struct__: No}", fn -> Sqids.encode(sqids, [33]) end
    end

    test "encode!/2: invalid sqids" do
      sqids = :no
      assert_raise ArgumentError, "argument error: :no", fn -> Sqids.encode!(sqids, [33]) end

      sqids = %{a: 55}
      assert_raise ArgumentError, "argument error: %{a: 55}", fn -> Sqids.encode!(sqids, [33]) end

      sqids = %{__struct__: No}
      assert_raise ArgumentError, "argument error: %{__struct__: No}", fn -> Sqids.encode!(sqids, [33]) end
    end

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: encode/2: number is not a non negative integer" do
        {:ok, instance} = new_sqids(unquote(access_type))

        input = [-1]
        assert_raise ArgumentError, "Number is not a non negative integer: -1", fn -> encode(instance, input) end

        input = [332, 43_543, -5, 23_434]
        assert_raise ArgumentError, "Number is not a non negative integer: -5", fn -> encode(instance, input) end

        input = [332, 43_543, 23_434, 233, -10]
        assert_raise ArgumentError, "Number is not a non negative integer: -10", fn -> encode(instance, input) end

        input = [55, "Oh no"]
        assert_raise ArgumentError, "Number is not a non negative integer: \"Oh no\"", fn -> encode(instance, input) end
      end

      test "#{access_type}: encode!/2: number is not a non negative integer" do
        {:ok, instance} = new_sqids(unquote(access_type))

        input = [-1]
        assert_raise ArgumentError, "Number is not a non negative integer: -1", fn -> encode!(instance, input) end

        input = [332, 43_543, -5, 23_434]
        assert_raise ArgumentError, "Number is not a non negative integer: -5", fn -> encode!(instance, input) end

        input = [332, 43_543, 23_434, 233, -10]
        assert_raise ArgumentError, "Number is not a non negative integer: -10", fn -> encode!(instance, input) end

        input = [55, "Oh no"]
        assert_raise ArgumentError, "Number is not a non negative integer: \"Oh no\"", fn -> encode!(instance, input) end
      end

      test "#{access_type}: encode/2: numbers not enumerable" do
        {:ok, instance} = new_sqids(unquote(access_type))

        input = {55}
        assert_raise ArgumentError, "Numbers not enumerable: {55}", fn -> encode(instance, input) end

        input = 3.5346
        assert_raise ArgumentError, "Numbers not enumerable: 3.5346", fn -> encode(instance, input) end

        input = "56"
        assert_raise ArgumentError, "Numbers not enumerable: \"56\"", fn -> encode(instance, input) end

        input = :"42"
        assert_raise ArgumentError, "Numbers not enumerable: :\"42\"", fn -> encode(instance, input) end
      end

      test "#{access_type}: encode!/2: numbers not enumerable" do
        {:ok, instance} = new_sqids(unquote(access_type))

        input = {55}
        assert_raise ArgumentError, "Numbers not enumerable: {55}", fn -> encode!(instance, input) end

        input = 3.5346
        assert_raise ArgumentError, "Numbers not enumerable: 3.5346", fn -> encode!(instance, input) end

        input = "56"
        assert_raise ArgumentError, "Numbers not enumerable: \"56\"", fn -> encode!(instance, input) end

        input = :"42"
        assert_raise ArgumentError, "Numbers not enumerable: :\"42\"", fn -> encode!(instance, input) end
      end
    end
  end

  defmodule AdditionalDecodingScenarios do
    @moduledoc false
    use ExUnit.Case, async: true

    import SqidsTest.Shared

    test "decode!/2: invalid sqids" do
      sqids = :no
      assert_raise ArgumentError, "argument error: :no", fn -> Sqids.decode!(sqids, "0") end

      sqids = %{a: 55}
      assert_raise ArgumentError, "argument error: %{a: 55}", fn -> Sqids.decode!(sqids, "0") end

      sqids = %{__struct__: No}
      assert_raise ArgumentError, "argument error: %{__struct__: No}", fn -> Sqids.decode!(sqids, "0") end
    end

    for access_type <- [:"Direct API", :"Using module"] do
      test "#{access_type}: decode!/2: id is not a string or valid UTF-8" do
        {:ok, instance} = new_sqids(unquote(access_type))

        input = ~c"555"
        assert_raise ArgumentError, ~r/Id is not a string: .+/, fn -> decode!(instance, input) end

        input = 10_432_345
        assert_raise ArgumentError, "Id is not a string: 10432345", fn -> decode!(instance, input) end

        input = "0000" <> <<128>>
        assert_raise ArgumentError, "Id is not utf8: <<48, 48, 48, 48, 128>>", fn -> decode!(instance, input) end
      end

      test "#{access_type}: decode!/2: id has unknown chars" do
        {:ok, instance} = new_sqids(unquote(access_type), alphabet: "01234")

        input = "5"
        assert decode!(instance, input) === []

        input = "011015"
        assert decode!(instance, input) === []

        input = "011015143"
        assert decode!(instance, input) === []

        input = "000ë5"
        assert decode!(instance, input) === []
      end
    end
  end
end

# doctest_file was added on Elixir 1.15
if Version.match?(System.version(), "~> 1.15") do
  defmodule FileDoctests do
    @moduledoc false
    use ExUnit.Case, async: true

    doctest_file("README.md")
  end
end
