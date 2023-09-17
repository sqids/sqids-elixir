defmodule Sqids do
  @moduledoc false
  alias Sqids.Alphabet

  ## Constants

  @default_alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  @default_min_length 0
  @default_blocklist_entries "blocklist/one_word_per_line.txt" |> File.read!() |> String.split("\n", trim: true)

  ## Types

  defmodule Ctx do
    @moduledoc false
    @enforce_keys [:alphabet, :min_length, :blocklist]
    defstruct [:alphabet, :min_length, :blocklist]

    @opaque t :: %__MODULE__{
              # url-safe characters
              alphabet: binary,
              # the minimum length IDs should be
              min_length: non_neg_integer,
              # a list of words that shouldn't appear anywhere in the IDs
              blocklist: MapSet.t(String.t())
            }
  end

  ## API Functions

  def new(opts \\ []) do
    alphabet_str = opts[:alphabet] || @default_alphabet
    min_length = opts[:min_length] || @default_min_length
    blocklist = opts[:blocklist] || @default_blocklist_entries

    with {:ok, shuffled_alphabet} <- Alphabet.new_shuffled(alphabet_str),
         :ok <- validate_min_length(min_length) do
      {:ok,
       %Ctx{
         alphabet: shuffled_alphabet,
         min_length: min_length,
         blocklist: filter_blocklist(blocklist, alphabet_str)
       }}
    else
      {:error, _} = error ->
        error
    end
  end

  def encode!(ctx, numbers) do
    {:ok, string} = encode(ctx, numbers)
    string
  end

  defp encode(%Ctx{} = ctx, numbers) do
    case validate_numbers_are_valid(numbers) do
      {:ok, numbers_list} ->
        encode_numbers(ctx, numbers_list)

      {:error, _} = error ->
        error
    end
  end

  ## Internal Functions

  defp validate_min_length(min_length) do
    if not is_integer(min_length) or min_length < 0 do
      {:error, {:min_length_must_be_a_non_negative_integer, min_length}}
    else
      :ok
    end
  end

  defp filter_blocklist(blocklist, alphabet_str) do
    alphabet_graphemes_downcased = alphabet_str |> String.downcase() |> String.graphemes()

    blocklist
    |> Enum.reduce(_acc = [], &filter_blocklist_entry(&1, &2, alphabet_graphemes_downcased))
    |> MapSet.new()
  end

  defp filter_blocklist_entry(word, acc, alphabet_graphemes_downcased) do
    if String.length(word) < 3 do
      acc
    else
      word_downcased = String.downcase(word)
      word_graphemes_downcased = String.graphemes(word_downcased)

      if Enum.all?(word_graphemes_downcased, &Enum.member?(alphabet_graphemes_downcased, &1)) do
        [word_downcased | acc]
      else
        acc
      end
    end
  end

  defp validate_numbers_are_valid(numbers) do
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
    encode_numbers_recur(ctx, list, _increment = 0)
  end

  defp encode_numbers_recur(ctx, _list, increment) when increment > byte_size(ctx.alphabet) do
    # We've reached max attempts
    {:error, {:reached_max_attempts_to_regenerate_the_id, increment - 1}}
  end

  defp encode_numbers_recur(ctx, list, increment) do
    alphabet = ctx.alphabet
    alphabet_size = Alphabet.size(alphabet)

    alphabet_split_offset = get_semi_random_offset_from_input_numbers(list, alphabet, alphabet_size)

    # if there's a non-zero `increment`, it's an internal attempt to regenerate the ID
    alphabet_split_offset = rem(alphabet_split_offset + increment, alphabet_size)

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

    # FIXME check for infixes
    if MapSet.member?(ctx.blocklist, id) do
      # ID has a blocked word, restart with a +1 increment
      encode_numbers_recur(ctx, list, increment + 1)
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
end
