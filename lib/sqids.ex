defmodule Sqids do
  @moduledoc false
  alias Sqids.Alphabet

  ## Constants

  # url-safe characters
  @default_alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  @default_min_length 0
  @default_blocklist_words "blocklist/one_word_per_line.txt" |> File.read!() |> String.split("\n", trim: true)

  @min_length_range 0..255
  @min_blocklist_word_length 3

  ## Types

  defmodule Ctx do
    @moduledoc false

    @type opts :: [
            alphabet: String.t(),
            min_length: non_neg_integer,
            blocklist: Enumerable.t(String.t())
          ]

    @enforce_keys [:alphabet, :min_length, :blocklist]
    defstruct [:alphabet, :min_length, :blocklist]

    @type t :: %__MODULE__{
            alphabet: Alphabet.t(),
            # the minimum length IDs should be
            min_length: non_neg_integer,
            # a list of words that shouldn't appear anywhere in the IDs
            blocklist: Sqids.Blocklist.t()
          }
  end

  defmodule Blocklist do
    @moduledoc false
    defstruct exact_matches: MapSet.new(), prefixes_and_suffixes: [], matches_anywhere: []

    @type t :: %__MODULE__{
            exact_matches: MapSet.t(String.t()),
            prefixes_and_suffixes: [String.t()],
            matches_anywhere: [String.t()]
          }
  end

  ## API Functions

  @spec new(Ctx.opts()) :: {:ok, Ctx.t()} | {:error, term}
  def new(opts \\ []) do
    alphabet_str = opts[:alphabet] || @default_alphabet
    min_length = opts[:min_length] || @default_min_length
    blocklist_words = opts[:blocklist] || @default_blocklist_words

    with {:ok, shuffled_alphabet} <- Alphabet.new_shuffled(alphabet_str),
         :ok <- validate_min_length(min_length) do
      {:ok,
       %Ctx{
         alphabet: shuffled_alphabet,
         min_length: min_length,
         blocklist: new_blocklist(blocklist_words, alphabet_str)
       }}
    else
      {:error, _} = error ->
        error
    end
  end

  @spec encode!(Ctx.t(), [non_neg_integer]) :: String.t()
  def encode!(ctx, numbers) do
    {:ok, string} = encode(ctx, numbers)
    string
  end

  @spec encode(Ctx.t(), [non_neg_integer]) :: {:ok, String.t()} | {:error, term}
  def encode(%Ctx{} = ctx, numbers) do
    case validate_numbers(numbers) do
      {:ok, numbers_list} ->
        encode_numbers(ctx, numbers_list)

      {:error, _} = error ->
        error
    end
  end

  @spec decode!(Ctx.t(), String.t()) :: [non_neg_integer]
  def decode!(ctx, id) do
    {:ok, numbers} = decode(ctx, id)
    numbers
  end

  @spec decode(Ctx.t(), String.t()) :: {:ok, [non_neg_integer]} | {:error, term}
  def decode(%Ctx{} = ctx, id) do
    case validate_id(ctx, id) do
      :ok ->
        decode_valid_id(ctx, id)

      :empty_id ->
        # If id is empty, return an empty list
        {:ok, []}

      :unknown_chars_in_id ->
        # Follow the spec's behaviour and return an empty list
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  ## Internal Functions

  @doc false
  def default_alphabet, do: @default_alphabet

  defp validate_min_length(min_length) do
    if not is_integer(min_length) or min_length not in @min_length_range do
      {:error, {:min_length_not_an_integer_in_range, min_length, range: @min_length_range}}
    else
      :ok
    end
  end

  defp new_blocklist(words, alphabet_str) do
    alphabet_graphemes_downcased = alphabet_str |> String.downcase() |> String.graphemes() |> MapSet.new()
    sort_fun = fn word -> {String.length(word), word} end

    words
    |> Enum.uniq()
    |> Enum.reduce(
      _acc0 = %Blocklist{},
      &maybe_new_blocklist_entry(&1, &2, alphabet_graphemes_downcased)
    )
    |> then(fn blocklist ->
      %{
        blocklist
        | prefixes_and_suffixes: Enum.sort_by(blocklist.prefixes_and_suffixes, sort_fun),
          matches_anywhere: Enum.sort_by(blocklist.matches_anywhere, sort_fun)
      }
    end)
  end

  defp maybe_new_blocklist_entry(word, blocklist, alphabet_graphemes_downcased) do
    downcased_word = String.downcase(word)
    downcased_length = String.length(downcased_word)

    cond do
      downcased_length < @min_blocklist_word_length ->
        # Word is too short to include
        blocklist

      not (downcased_word |> String.graphemes() |> Enum.all?(&MapSet.member?(alphabet_graphemes_downcased, &1))) ->
        # Word contains characters that are not part of the alphabet
        blocklist

      downcased_length === @min_blocklist_word_length ->
        # Short words have to match completely to avoid too many matches
        %{blocklist | exact_matches: MapSet.put(blocklist.exact_matches, downcased_word)}

      String.match?(downcased_word, ~r/\d/u) ->
        # Words with leet speak replacements are visible mostly on the ends of an id
        %{blocklist | prefixes_and_suffixes: [downcased_word | blocklist.prefixes_and_suffixes]}

      true ->
        # Otherwise, check for word anywhere within an id
        %{blocklist | matches_anywhere: [downcased_word | blocklist.matches_anywhere]}
    end
  end

  ## Internal Functions: Encoding

  defp validate_numbers(numbers) do
    numbers
    |> Enum.find(&(not is_valid_number(&1)))
    |> case do
      nil ->
        numbers_list = Enum.to_list(numbers)
        {:ok, numbers_list}

      invalid_number ->
        {:error, {:number_must_be_a_non_negative_integer, invalid_number}}
    end
  end

  defp is_valid_number(number), do: is_integer(number) and number >= 0

  # if no numbers passed, return an empty string
  defp encode_numbers(_ctx, [] = _list), do: {:ok, ""}

  defp encode_numbers(ctx, list) do
    attempt_to_encode_numbers(ctx, list, _attempt_index = 0)
  end

  defp attempt_to_encode_numbers(ctx, list, attempt_index) do
    if attempt_index > Alphabet.size(ctx.alphabet) do
      # We've reached max attempts
      {:error, {:reached_max_attempts_to_regenerate_the_id, attempt_index - 1}}
    else
      do_attempt_to_encode_numbers(ctx, list, attempt_index)
    end
  end

  defp do_attempt_to_encode_numbers(ctx, list, attempt_index) do
    alphabet = ctx.alphabet
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

    id = handle_min_length_requirement(id_iodata, alphabet, ctx.min_length)

    if is_blocked_id(ctx.blocklist, id) do
      # ID has a blocked word, restart with a +1 attempt_index
      attempt_to_encode_numbers(ctx, list, attempt_index + 1)
    else
      {:ok, id}
    end
  end

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

  defp encode_input_numbers(list, alphabet) do
    encode_input_numbers_recur(list, alphabet, _acc = [])
  end

  defp encode_input_numbers_recur([input | next], alphabet, acc) do
    encoded_number = encode_input_number(input, alphabet)

    if next != [] do
      separator = Alphabet.char_at!(alphabet, 0)
      alphabet = Alphabet.shuffle(alphabet)
      acc = [acc, encoded_number, separator]
      encode_input_numbers_recur(next, alphabet, acc)
    else
      acc = [acc, encoded_number]
      {acc, alphabet}
    end
  end

  defp encode_input_number(input, alphabet) do
    alphabet_size_without_separator = Alphabet.size(alphabet) - 1
    encode_input_number_recur(input, alphabet, alphabet_size_without_separator, _acc = [])
  end

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

  defp is_blocked_id(blocklist, id) do
    downcased_id = String.downcase(id)
    downcased_size = byte_size(downcased_id)

    cond do
      downcased_size < @min_blocklist_word_length ->
        false

      downcased_size === @min_blocklist_word_length ->
        MapSet.member?(blocklist.exact_matches, downcased_id)

      true ->
        String.contains?(downcased_id, blocklist.matches_anywhere) or
          String.starts_with?(downcased_id, blocklist.prefixes_and_suffixes) or
          String.ends_with?(downcased_id, blocklist.prefixes_and_suffixes)
    end
  end

  ## Internal Functions: Decoding

  defp validate_id(_ctx, ""), do: :empty_id

  defp validate_id(ctx, id) when is_binary(id) do
    if are_all_chars_in_id_known(id, ctx.alphabet) do
      :ok
    else
      :unknown_chars_in_id
    end
  end

  defp validate_id(_ctx, not_a_string) do
    {:error, {:id_not_a_string, not_a_string}}
  end

  defp are_all_chars_in_id_known(id, alphabet) do
    id |> String.graphemes() |> Enum.all?(&Alphabet.is_known_symbol(alphabet, &1))
  end

  defp decode_valid_id(ctx, id) do
    alphabet = ctx.alphabet

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

  defp decode_valid_id_chunk(chunk, alphabet) do
    alphabet_size_without_separator = Alphabet.size(alphabet) - 1
    decode_valid_id_chunk_recur(chunk, alphabet, alphabet_size_without_separator, _acc = 0)
  end

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

  defp finish_decoding_valid_id(acc) do
    numbers = Enum.reverse(acc)
    {:ok, numbers}
  end
end
