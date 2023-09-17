defmodule Sqids do
  @moduledoc false
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

    with :ok <- validate_alphabet_graphemes_are_not_multibyte(alphabet_str),
         :ok <- validate_alphabet_length(alphabet_str),
         :ok <- validate_alphabet_has_unique_graphemes(alphabet_str),
         :ok <- validate_min_length(min_length) do
      {:ok,
       %Ctx{
         alphabet: shuffle_alphabet(alphabet_str),
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

  defp validate_alphabet_graphemes_are_not_multibyte(alphabet_str) do
    alphabet_graphemes = String.graphemes(alphabet_str)

    case Enum.filter(alphabet_graphemes, &is_grapheme_multibyte/1) do
      [] ->
        :ok

      multibyte_graphemes ->
        {:error, {:alphabet_cannot_contain_multibyte_graphemes, multibyte_graphemes}}
    end
  end

  defp is_grapheme_multibyte(grapheme), do: byte_size(grapheme) != 1

  defp validate_alphabet_length(alphabet_str) do
    if String.length(alphabet_str) < 3 do
      {:error, {:alphabet_length_must_be_at_least_3, alphabet_str}}
    else
      :ok
    end
  end

  defp validate_alphabet_has_unique_graphemes(alphabet_str) do
    [
      &:unicode.characters_to_nfc_binary/1,
      &:unicode.characters_to_nfd_binary/1,
      &:unicode.characters_to_nfkc_binary/1,
      &:unicode.characters_to_nfkd_binary/1
    ]
    |> Enum.find_value(&find_repeated_graphemes_in_alphabet(alphabet_str, &1))
    |> case do
      nil ->
        :ok

      repeated_graphemes ->
        {:error, {:alphabet_must_contain_unique_graphemes, repeated_graphemes}}
    end
  end

  defp find_repeated_graphemes_in_alphabet(alphabet_str, normalization_fun) do
    normalized_graphemes = alphabet_str |> normalization_fun.() |> String.graphemes()
    unique_graphemes = Enum.uniq(normalized_graphemes)

    case unique_graphemes -- normalized_graphemes do
      [] ->
        nil

      repeated_graphemes ->
        repeated_graphemes
    end
  end

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
    offset = get_semi_random_offset_from_input_numbers(ctx, list)

    # if there's a non-zero `increment`, it's an internal attempt to regenerate the ID
    offset = rem(offset + increment, byte_size(ctx.alphabet))

    # rearrange the alphabet so that the second half goes in front of the first
    iteration_alphabet =
      :binary.part(ctx.alphabet, offset, byte_size(ctx.alphabet) - offset) <>
        :binary.part(ctx.alphabet, 0, offset)

    # `prefix` is the first grapheme in the generated ID, used for randomization
    prefix = String.at(iteration_alphabet, 0)

    # reverse alphabet
    iteration_alphabet = reverse_binary(iteration_alphabet)

    {iteration_alphabet, id} = encode_input_numbers(iteration_alphabet, list)

    # final ID will always have the `prefix` character at the beginning
    id = prefix <> id

    id = handle_min_length_requirement(iteration_alphabet, ctx.min_length, id)

    # FIXME check for infixes
    if MapSet.member?(ctx.blocklist, id) do
      # ID has a blocked word, restart with a +1 increment
      encode_numbers_recur(ctx, list, increment + 1)
    else
      {:ok, id}
    end
  end

  defp get_semi_random_offset_from_input_numbers(ctx, list) do
    list
    |> Enum.zip(0..(length(list) - 1))
    |> Enum.reduce(
      _acc0 = length(list),
      fn {number, index}, acc ->
        alphabet_pos = rem(number, byte_size(ctx.alphabet))
        <<codepoint>> = :binary.part(ctx.alphabet, alphabet_pos, 1)
        acc + codepoint + index
      end
    )
  end

  defp reverse_binary(binary) do
    binary
    |> :erlang.binary_to_list()
    |> :lists.reverse()
    |> :erlang.list_to_binary()
  end

  defp encode_input_numbers(iteration_alphabet, list) do
    list
    |> Enum.zip(0..(length(list) - 1))
    |> Enum.reverse()
    |> Enum.reduce(
      {iteration_alphabet, _acc0 = []},
      fn {number, index}, {iteration_alphabet, acc} ->
        <<separator, iteration_alphabet_without_separator::bytes>> = iteration_alphabet

        # if not last number
        acc =
          if index != length(list) - 1 do
            # separator is used to isolate numbers within the id
            [separator | acc]
          else
            acc
          end

        encoded_number = number_to_id(number, iteration_alphabet_without_separator)
        acc = [encoded_number | acc]

        # shuffle on every reduction
        iteration_alphabet = shuffle_alphabet(iteration_alphabet)

        {iteration_alphabet, acc}
      end
    )
    |> then(fn {iteration_alphabet, id_graphemes} ->
      # join all parts to form an ID
      id = Enum.join(id_graphemes, "")
      {iteration_alphabet, id}
    end)
  end

  defp number_to_id(number, alphabet) do
    result = number
    last_byte = byte_at_pos(alphabet, rem(result, byte_size(alphabet)))
    id_acc = [last_byte]
    result = div(result, byte_size(alphabet))

    number_to_id_recur(result, alphabet, id_acc)
  end

  defp number_to_id_recur(prev_result, alphabet, id_acc) do
    if prev_result > 0 do
      prev_byte = byte_at_pos(alphabet, rem(prev_result, byte_size(alphabet)))
      result = div(prev_result, byte_size(alphabet))
      id_acc = [prev_byte | id_acc]
      number_to_id_recur(result, alphabet, id_acc)
    else
      :erlang.list_to_binary(id_acc)
    end
  end

  defp byte_at_pos(binary, pos) do
    <<byte>> = :binary.part(binary, pos, 1)
    byte
  end

  defp shuffle_alphabet(iteration_alphabet) do
    array = iteration_alphabet |> :erlang.binary_to_list() |> List.to_tuple()

    # deterministic shuffle
    0..(byte_size(iteration_alphabet) - 2)
    |> Enum.reduce(
      array,
      fn i, acc ->
        j = tuple_size(acc) - (i + 1)

        codepoint_at_i = elem(acc, i)
        codepoint_at_j = elem(acc, j)

        r = rem(i * j + codepoint_at_i + codepoint_at_j, tuple_size(acc))
        codepoint_at_r = elem(acc, r)

        acc = Kernel.put_elem(acc, i, codepoint_at_r)
        acc = Kernel.put_elem(acc, r, codepoint_at_i)
        acc
      end
    )
    |> Tuple.to_list()
    |> :erlang.list_to_binary()
  end

  defp handle_min_length_requirement(iteration_alphabet, min_length, id) do
    if byte_size(id) < min_length do
      # append a separator
      <<separator, _::bytes>> = iteration_alphabet
      id = <<id::bytes, separator>>

      # + however much alphabet is needed
      keep_appending_separator_while_needed(iteration_alphabet, min_length, id)
    else
      id
    end
  end

  defp keep_appending_separator_while_needed(iteration_alphabet, min_length, id) do
    if byte_size(id) < min_length do
      iteration_alphabet = shuffle_alphabet(iteration_alphabet)

      length_missing = min_length - byte_size(id)
      alphabet_slice_length = min(length_missing, byte_size(iteration_alphabet))
      alphabet_slice = :binary.part(iteration_alphabet, 0, alphabet_slice_length)
      id = id <> alphabet_slice
      keep_appending_separator_while_needed(iteration_alphabet, min_length, id)
    else
      id
    end
  end
end
