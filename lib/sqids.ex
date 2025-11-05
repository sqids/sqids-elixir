defmodule Sqids do
  @moduledoc """
  Sqids API

  > ℹ️ Check out the [docs entry page](readme.html) on how to make
  > `Sqids` easier to use by not passing the context on every encode/decode
  > call, through either:
  > * creation of context at compile time under a module attribute,
  > * or the `use Sqids` macro to generate functions that retrieve context transparently.
  """
  @moduledoc since: "0.1.0"

  alias Sqids.Alphabet
  alias Sqids.Blocklist

  ## Constants

  # url-safe characters
  @default_alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  @default_min_length 0

  @min_length_range 0..255
  @min_blocklist_word_length 3

  ## Types

  @typedoc "Opts for `new/1`"
  @type opts :: [
          alphabet: String.t(),
          min_length: non_neg_integer,
          blocklist: enumerable(String.t())
        ]

  @typedoc "Wrapper type for Elixir 1.13 or older"
  if Version.match?(System.version(), "~> 1.14") do
    @type enumerable(t) :: Enumerable.t(t)
  else
    @type enumerable(t) :: [t] | Enumerable.t()
  end

  @enforce_keys [:alphabet, :min_length, :blocklist]
  defstruct [:alphabet, :min_length, :blocklist]

  @typedoc "Context for Sqids"
  @opaque t :: %__MODULE__{
            alphabet: Alphabet.t(),
            # the minimum length IDs should be
            min_length: non_neg_integer,
            # words that shouldn't appear anywhere in the IDs
            blocklist: Blocklist.t()
          }

  ## Guards

  defguardp is_proper_list(v) when length(v) >= 0

  ## API Functions

  @doc """
  Creates a context used for both encoding and decoding.

  Can receive a list of zero or more `t:opts/0`:
  * `alphabet`: a case and order -sensitive string containing the chars of which generated IDs will be made of;
  * `min_length`: the minimum length of your generated IDs (padding added if needed);
  * `blocklist`: an enumerable collection of strings which shouldn't appear in generated IDs.

  Returns error if any of the `t:opts/0` is invalid.
  """
  @spec new(opts()) :: {:ok, t()} | {:error, term}
  def new(opts \\ [])

  def new(opts) when is_proper_list(opts) do
    alphabet_str = opts[:alphabet] || @default_alphabet
    min_length = opts[:min_length] || @default_min_length
    blocklist_words = opts[:blocklist] || read_default_blocklist_words!()

    with {:ok, alphabet} <- Alphabet.new(alphabet_str),
         alphabet = Alphabet.shuffle(alphabet),
         :ok <- validate_min_length(min_length),
         {:ok, blocklist} <- Blocklist.new(blocklist_words, @min_blocklist_word_length, alphabet_str) do
      {:ok,
       %Sqids{
         alphabet: alphabet,
         min_length: min_length,
         blocklist: blocklist
       }}
    else
      {:error, {tag, _} = reason}
      when tag in [
             :alphabet_is_not_an_utf8_string,
             :min_length_is_not_an_integer_in_range,
             :blocklist_is_not_enumerable,
             :some_words_in_blocklist_are_not_utf8_strings
           ] ->
        raise %ArgumentError{message: error_reason_to_string(reason)}

      {:error, _} = error ->
        error
    end
  end

  def new(opts) do
    raise %ArgumentError{message: "Opts not a proper list: #{inspect(opts)}"}
  end

  @doc """
  Like `new/0` and `new/1` but raises in case of error.
  """
  @doc since: "0.1.1"
  @spec new!(opts()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, sqids} ->
        sqids

      {:error, reason} ->
        raise %ArgumentError{message: error_reason_to_string(reason)}
    end
  end

  @doc """
  Tries to encode zero or more `numbers` into as an `id`, according to
  `sqids`'s alphabet, blocklist, and minimum length. Returns an error
  otherwise.
  """
  @spec encode(sqids, numbers) :: {:ok, id} | {:error, term}
        when sqids: t(), numbers: enumerable(non_neg_integer), id: String.t()
  def encode(%Sqids{} = sqids, numbers) do
    case validate_numbers(numbers) do
      {:ok, numbers_list} ->
        encode_numbers(sqids, numbers_list)

      {:error, reason} ->
        raise %ArgumentError{message: error_reason_to_string(reason)}
    end
  end

  def encode(sqids, _numbers), do: :erlang.error({:badarg, sqids})

  @doc """
  Encodes zero or more `numbers` into an `id`, according to `sqids`'s alphabet,
  blocklist, and minimum length. Raises in case of error.
  """
  @spec encode!(sqids, numbers) :: id
        when sqids: t(), numbers: enumerable(non_neg_integer), id: String.t()
  def encode!(sqids, numbers) do
    case encode(sqids, numbers) do
      {:ok, string} ->
        string

      {:error, {:all_id_generation_attempts_were_censored, _nr_of_attempts} = reason} ->
        raise error_reason_to_string(reason)
    end
  end

  @doc """
  Decodes an `id` into zero or more `numbers` according to `sqids`'s alphabet.

  Like in the [reference implementation](https://github.com/sqids/sqids-spec),
  the presence of unknown characters within `id` will result in an empty list
  being returned.
  """
  @spec decode!(sqids, id) :: numbers
        when sqids: t(), id: String.t(), numbers: [non_neg_integer]
  def decode!(sqids, id) do
    {:ok, numbers} = decode(sqids, id)
    numbers

    # {:error, reason} ->
    #   raise error_reason_to_string(reason)
  end

  ## Internal Functions

  @doc false
  @spec default_alphabet :: String.t()
  def default_alphabet, do: @default_alphabet

  @doc false
  @spec dialyzed_ctx(%__MODULE__{}) :: t
  def dialyzed_ctx(%__MODULE__{} = sqids) do
    # This function is required to work around Dialyzer warnings on violating
    # type opacity when Sqids context is placed in a module attribute, since it
    # becomes "hardcoded" from Dialyzer's point of view.
    sqids
  end

  defp validate_min_length(min_length) do
    if not is_integer(min_length) or min_length not in @min_length_range do
      {:error, {:min_length_is_not_an_integer_in_range, value: min_length, range: @min_length_range}}
    else
      :ok
    end
  end

  @doc false
  @spec different_opts(opts, opts) :: opts
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def different_opts(opts1, opts2) do
    alphabet_str1 = opts1[:alphabet] || @default_alphabet
    min_length1 = opts1[:min_length] || @default_min_length
    blocklist_words1 = opts1[:blocklist] || :default

    alphabet_str2 = opts2[:alphabet] || @default_alphabet
    min_length2 = opts2[:min_length] || @default_min_length
    blocklist_words2 = opts2[:blocklist] || :default

    different_opts = []

    different_opts =
      if alphabet_str2 === alphabet_str1 do
        different_opts
      else
        different_opts ++ [alphabet: alphabet_str2]
      end

    different_opts =
      if min_length2 === min_length1 do
        different_opts
      else
        different_opts ++ [min_length: min_length2]
      end

    if blocklist_words2 === :default !== (blocklist_words1 === :default) or
         (blocklist_words2 !== :default and
            blocklist_words1 !== :default and
            Enum.sort(Enum.uniq(blocklist_words2)) !== Enum.sort(Enum.uniq(blocklist_words1))) do
      different_opts ++ [blocklist: blocklist_words2]
    else
      different_opts
    end
  end

  ## Internal Functions: Encoding

  @spec read_default_blocklist_words! :: [String.t()]
  defp read_default_blocklist_words! do
    :sqids
    |> :code.priv_dir()
    |> Path.join("blocklist.txt")
    |> File.read!()
    |> String.split(["\n", "\r"], trim: true)
  end

  defp validate_numbers(numbers) do
    Enum.find(numbers, &(not valid_number?(&1)))
  catch
    :error, %Protocol.UndefinedError{value: ^numbers} ->
      {:error, {:numbers_not_enumerable, numbers}}
  else
    nil ->
      numbers_list = Enum.to_list(numbers)
      {:ok, numbers_list}

    invalid_number ->
      {:error, {:number_is_not_a_non_negative_integer, invalid_number}}
  end

  defp valid_number?(number), do: is_integer(number) and number >= 0

  # if no numbers passed, return an empty string
  @spec encode_numbers(t(), [non_neg_integer]) :: {:ok, String.t()} | {:error, term}
  defp encode_numbers(_sqids, [] = _list), do: {:ok, ""}

  defp encode_numbers(sqids, list) do
    attempt_to_encode_numbers(sqids, list, _attempt_index = 0)
  end

  @spec attempt_to_encode_numbers(t(), [non_neg_integer], non_neg_integer) ::
          {:ok, String.t()} | {:error, term}
  defp attempt_to_encode_numbers(sqids, list, attempt_index) do
    if attempt_index > Alphabet.size(sqids.alphabet) do
      # We've reached max attempts
      {:error, {:all_id_generation_attempts_were_censored, _nr_of_attempts = attempt_index - 1}}
    else
      do_attempt_to_encode_numbers(sqids, list, attempt_index)
    end
  end

  @spec do_attempt_to_encode_numbers(t(), [non_neg_integer], non_neg_integer) ::
          {:ok, String.t()} | {:error, term}
  defp do_attempt_to_encode_numbers(sqids, list, attempt_index) do
    alphabet = sqids.alphabet
    alphabet_size = Alphabet.size(alphabet)

    alphabet_split_offset = get_semi_random_offset_from_input_numbers(list, alphabet, alphabet_size)

    # if there's a non-zero `attempt_index`, it's an internal attempt to regenerate the ID
    alphabet_split_offset = rem(alphabet_split_offset + attempt_index, alphabet_size)

    # rearrange the alphabet so that the second half goes in front of the first
    alphabet = Alphabet.split_and_exchange!(alphabet, alphabet_split_offset)

    # `id_prefix` is the first char in the generated ID, used for randomization
    id_prefix = Alphabet.char_at!(alphabet, 0)

    # reverse alphabet
    alphabet = Alphabet.reverse(alphabet)

    {id_iodata, alphabet} = encode_input_numbers(list, alphabet)

    # final ID will always have the `prefix` character at the beginning
    id_iodata = [id_prefix, id_iodata]

    id = handle_min_length_requirement(id_iodata, alphabet, sqids.min_length)

    if Blocklist.blocked_id?(sqids.blocklist, id) do
      # ID has a blocked word, restart with a +1 attempt_index
      attempt_to_encode_numbers(sqids, list, attempt_index + 1)
    else
      {:ok, id}
    end
  end

  @spec get_semi_random_offset_from_input_numbers([non_neg_integer], Alphabet.t(), pos_integer) ::
          non_neg_integer
  defp get_semi_random_offset_from_input_numbers(list, alphabet, alphabet_size) do
    list_length = length(list)

    list
    |> Enum.zip(0..(list_length - 1))
    |> Enum.reduce(
      _acc0 = list_length,
      fn {number, index}, acc ->
        alphabet_index = rem(number, alphabet_size)
        char = Alphabet.char_at!(alphabet, alphabet_index)
        acc + char + index
      end
    )
  end

  @spec encode_input_numbers([non_neg_integer], Alphabet.t()) :: {iodata(), Alphabet.t()}
  defp encode_input_numbers(list, alphabet) do
    encode_input_numbers_recur(list, alphabet, _acc = [])
  end

  defp encode_input_numbers_recur([input | next], alphabet, acc) do
    encoded_number = encode_input_number(input, alphabet)

    if next === [] do
      acc = [acc, encoded_number]
      {acc, alphabet}
    else
      separator = Alphabet.char_at!(alphabet, 0)
      alphabet = Alphabet.shuffle(alphabet)
      acc = [acc, encoded_number, separator]
      encode_input_numbers_recur(next, alphabet, acc)
    end
  end

  @spec encode_input_number(non_neg_integer, Alphabet.t()) :: [byte, ...]
  defp encode_input_number(input, alphabet) do
    alphabet_size_without_separator = Alphabet.size(alphabet) - 1
    encode_input_number_recur(input, alphabet, alphabet_size_without_separator, _acc = [])
  end

  @spec encode_input_number_recur(non_neg_integer, Alphabet.t(), pos_integer, [byte]) :: [byte, ...]
  defp encode_input_number_recur(input, alphabet, alphabet_size_without_separator, acc) do
    if input !== 0 or acc === [] do
      input_remainder = rem(input, alphabet_size_without_separator)
      char = Alphabet.char_at!(alphabet, input_remainder + 1)
      input = div(input, alphabet_size_without_separator)
      acc = [char | acc]
      encode_input_number_recur(input, alphabet, alphabet_size_without_separator, acc)
    else
      acc
    end
  end

  @spec handle_min_length_requirement(iodata, Alphabet.t(), non_neg_integer) ::
          String.t()
  defp handle_min_length_requirement(id_iodata, alphabet, min_length) do
    case IO.iodata_to_binary(id_iodata) do
      id when byte_size(id) >= min_length ->
        # hopefully the common case
        id

      insufficient_id ->
        # append a separator
        separator = Alphabet.char_at!(alphabet, 0)
        id_iodata = [insufficient_id, separator]
        id_size = byte_size(insufficient_id) + 1

        # + however much alphabet is needed
        keep_appending_separator_while_needed(id_iodata, id_size, alphabet, min_length)
    end
  end

  @spec keep_appending_separator_while_needed(iodata, non_neg_integer, Alphabet.t(), pos_integer) ::
          String.t()
  defp keep_appending_separator_while_needed(id_iodata, id_size, alphabet, min_length) do
    if id_size < min_length do
      alphabet = Alphabet.shuffle(alphabet)

      length_missing = min_length - id_size
      alphabet_slice_size = min(length_missing, Alphabet.size(alphabet))
      alphabet_slice_chars = Alphabet.get_slice_chars!(alphabet, alphabet_slice_size)

      id_iodata = [id_iodata, alphabet_slice_chars]
      id_size = id_size + alphabet_slice_size

      keep_appending_separator_while_needed(id_iodata, id_size, alphabet, min_length)
    else
      id = IO.iodata_to_binary(id_iodata)
      id
    end
  end

  ## Internal Functions: Decoding

  defp validate_id(_sqids, ""), do: :empty_id

  defp validate_id(sqids, id) when is_binary(id) do
    case String.valid?(id) and {:all_chars_known, are_all_chars_in_id_known(id, sqids.alphabet)} do
      {:all_chars_known, true} ->
        :ok

      {:all_chars_known, false} ->
        :unknown_chars_in_id

      false ->
        {:error, {:id_is_not_utf8, id}}
    end
  end

  defp validate_id(_sqids, not_a_string) do
    {:error, {:id_is_not_a_string, not_a_string}}
  end

  defp are_all_chars_in_id_known(id, alphabet) do
    id |> String.graphemes() |> Enum.all?(&Alphabet.known_symbol?(alphabet, &1))
  end

  @spec decode(t(), String.t()) :: {:ok, [non_neg_integer]}
  defp decode(%Sqids{} = sqids, id) do
    case validate_id(sqids, id) do
      :ok ->
        decode_valid_id(sqids, id)

      :empty_id ->
        # If id is empty, return an empty list
        {:ok, []}

      :unknown_chars_in_id ->
        # Follow the spec's behaviour and return an empty list
        {:ok, []}

      {:error, {tag, _} = reason} when tag in [:id_is_not_utf8, :id_is_not_a_string] ->
        raise %ArgumentError{message: error_reason_to_string(reason)}
    end
  end

  defp decode(sqids, _id), do: :erlang.error({:badarg, sqids})

  @spec decode_valid_id(t(), String.t()) :: {:ok, [non_neg_integer]}
  defp decode_valid_id(sqids, id) do
    alphabet = sqids.alphabet

    # first character is always the `prefix`
    <<prefix, id::bytes>> = id

    # `alphabet_split_offset` is the semi-random position that was generated during encoding
    alphabet_split_offset = Alphabet.index_of!(alphabet, prefix)

    # rearrange alphabet into its original form
    alphabet = Alphabet.split_and_exchange!(alphabet, alphabet_split_offset)

    # reverse alphabet
    alphabet = Alphabet.reverse(alphabet)

    decode_valid_id_recur(id, alphabet, _acc = [])
  end

  @spec decode_valid_id_recur(String.t(), Alphabet.t(), [non_neg_integer]) :: {:ok, [non_neg_integer]}
  defp decode_valid_id_recur("" = _id, _alphabet, acc) do
    finish_decoding_valid_id(acc)
  end

  defp decode_valid_id_recur(id, alphabet, acc) do
    separator = Alphabet.char_at!(alphabet, 0)

    case String.split(id, <<separator>>, parts: 2) do
      ["" = _chunk | _] ->
        # rest is junk characters
        finish_decoding_valid_id(acc)

      [last_chunk] ->
        number = decode_valid_id_chunk(last_chunk, alphabet)
        acc = [number | acc]
        finish_decoding_valid_id(acc)

      [chunk, id] ->
        number = decode_valid_id_chunk(chunk, alphabet)
        alphabet = Alphabet.shuffle(alphabet)
        acc = [number | acc]
        decode_valid_id_recur(id, alphabet, acc)
    end
  end

  @spec decode_valid_id_chunk(String.t(), Alphabet.t()) :: non_neg_integer
  defp decode_valid_id_chunk(chunk, alphabet) do
    alphabet_size_without_separator = Alphabet.size(alphabet) - 1
    decode_valid_id_chunk_recur(chunk, alphabet, alphabet_size_without_separator, _acc = 0)
  end

  @spec decode_valid_id_chunk_recur(String.t(), Alphabet.t(), pos_integer, non_neg_integer) :: non_neg_integer
  defp decode_valid_id_chunk_recur(chunk, alphabet, alphabet_size_without_separator, acc) do
    case chunk do
      <<char, chunk::bytes>> ->
        digit = Alphabet.index_of!(alphabet, char) - 1
        acc = acc * alphabet_size_without_separator + digit
        decode_valid_id_chunk_recur(chunk, alphabet, alphabet_size_without_separator, acc)

      <<>> ->
        acc
    end
  end

  @spec finish_decoding_valid_id([non_neg_integer]) :: {:ok, [non_neg_integer]}
  defp finish_decoding_valid_id(acc) do
    numbers = Enum.reverse(acc)
    {:ok, numbers}
  end

  defp error_reason_to_string({tag, details}) when is_atom(tag) do
    "#{prettify_error_tag(tag)}: #{inspect(details)}"
  end

  defp prettify_error_tag(tag) do
    [first_word | next_words] = tag |> Atom.to_string() |> String.split("_")
    first_word = String.capitalize(first_word)
    Enum.join([first_word | next_words], " ")
  end

  ## Code generation

  @doc """
  Returns Supervisor child spec for callback module.
  """
  @callback child_spec() :: Supervisor.child_spec()

  defmacro __using__([]) do
    quote do
      @behaviour Sqids

      ## API

      @spec child_spec(Sqids.opts()) :: Supervisor.child_spec()
      @doc """
      Returns Supervisor child spec for #{__MODULE__} and `opts`.
      """
      def child_spec(opts) do
        mfa = {__MODULE__, :start_link, [opts]}
        Sqids.Agent.child_spec(mfa)
      end

      @spec start_link(Sqids.opts()) :: {:ok, pid} | {:error, term}
      @doc """
      Starts `Sqids.Agent` for #{__MODULE__}.
      """
      def start_link(opts) do
        case __MODULE__.child_spec() do
          %{start: {__MODULE__, :start_link, [desired_opts]}} when desired_opts !== opts ->
            Sqids.Hacks.raise_exception_if_missed_desired_options(opts, desired_opts, __MODULE__)

          _child_spec ->
            :ok
        end

        shared_state_init = {&Sqids.new/1, [opts]}
        Sqids.Agent.start_link(__MODULE__, shared_state_init)
      end

      @doc """
      Encodes `numbers` into an `id`, according to `#{__MODULE__}`'s alphabet,
      blocklist, and minimum length. Raises in case of error.
      """
      @spec encode!(numbers) :: id
            when numbers: Sqids.enumerable(non_neg_integer), id: String.t()
      def encode!(numbers) do
        sqids = Sqids.Agent.get(__MODULE__)
        Sqids.encode!(sqids, numbers)
      end

      @doc """
      Tries to encode `numbers` into an `id`, according to `#{__MODULE__}`'s
      alphabet, blocklist, and minimum length. Returns an error otherwise.
      """
      @spec encode(numbers) :: {:ok, id} | {:error, term}
            when numbers: Sqids.enumerable(non_neg_integer), id: String.t()
      def encode(numbers) do
        sqids = Sqids.Agent.get(__MODULE__)
        Sqids.encode(sqids, numbers)
      end

      @doc """
      Decodes an `id` into zero or more `numbers`, according to
      `#{__MODULE__}`'s alphabet.
      """
      @spec decode!(id) :: numbers
            when id: String.t(), numbers: [non_neg_integer]
      def decode!(numbers) do
        sqids = Sqids.Agent.get(__MODULE__)
        Sqids.decode!(sqids, numbers)
      end
    end
  end
end
