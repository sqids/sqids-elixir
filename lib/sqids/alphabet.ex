defmodule Sqids.Alphabet do
  @moduledoc false

  @min_alphabet_length 3

  ## Types

  @opaque t :: %{required(index) => byte}
  @type index :: non_neg_integer

  @type new_error_reason ::
          {:alphabet_is_not_an_utf8_string, term}
          | {:alphabet_contains_multibyte_graphemes, [String.grapheme(), ...]}
          | {:alphabet_is_too_small, [min_length: pos_integer, alphabet: String.t()]}
          | {:alphabet_contains_repeated_graphemes, [String.grapheme(), ...]}

  ## API

  @spec new_shuffled(term) :: {:ok, t} | {:error, new_error_reason}
  def new_shuffled(alphabet_str) do
    with :ok <- validate_alphabet_is_utf8_string(alphabet_str),
         :ok <- validate_alphabet_graphemes_are_not_multibyte(alphabet_str),
         :ok <- validate_alphabet_length(alphabet_str),
         :ok <- validate_alphabet_has_unique_chars(alphabet_str) do
      alphabet = alphabet_str |> new_from_valid_str!() |> shuffle()
      {:ok, alphabet}
    else
      {:error, _} = error ->
        error
    end
  end

  @spec shuffle(t()) :: t()
  def shuffle(alphabet) do
    # deterministic shuffle
    alphabet_size = map_size(alphabet)

    Enum.reduce(0..(alphabet_size - 2), alphabet, fn i, alphabet ->
      j = alphabet_size - (i + 1)

      char_at_i = Map.fetch!(alphabet, i)
      char_at_j = Map.fetch!(alphabet, j)

      r = rem(i * j + char_at_i + char_at_j, alphabet_size)
      char_at_r = Map.fetch!(alphabet, r)

      alphabet = %{alphabet | i => char_at_r, r => char_at_i}
      alphabet
    end)
  end

  @spec size(t()) :: pos_integer
  def size(alphabet), do: map_size(alphabet)

  @spec char_at!(t(), index) :: byte
  def char_at!(alphabet, index), do: Map.fetch!(alphabet, index)

  @spec split_and_exchange!(t(), index) :: t()
  def split_and_exchange!(alphabet, split_index) when split_index in 0..(map_size(alphabet) - 1) do
    alphabet_size = map_size(alphabet)

    map(alphabet, fn {index, char} ->
      new_index =
        if index < split_index do
          alphabet_size - split_index + index
        else
          index - split_index
        end

      {new_index, char}
    end)
  end

  @spec reverse(t()) :: t()
  def reverse(alphabet) do
    alphabet_size = map_size(alphabet)

    map(alphabet, fn {index, char} ->
      new_index = alphabet_size - index - 1
      {new_index, char}
    end)
  end

  @spec get_slice_chars!(t(), pos_integer) :: [byte, ...]
  def get_slice_chars!(alphabet, size) when size in 1..map_size(alphabet) do
    Enum.reduce((size - 1)..0, _acc = [], fn index, acc -> [char_at!(alphabet, index) | acc] end)
  end

  @spec known_symbol?(t(), String.t()) :: boolean
  def known_symbol?(%{} = alphabet, <<arg_char>>) do
    Enum.any?(alphabet, fn {_index, char} -> arg_char === char end)
  end

  def known_symbol?(%{} = _alphabet, multibyte) when byte_size(multibyte) > 1 do
    false
  end

  @spec index_of!(t(), byte) :: index
  def index_of!(%{} = alphabet, char) do
    # It would be nice to optimize this.
    case Enum.find_value(alphabet, fn {index, byte} -> byte === char and index end) do
      nil -> raise "index was nil"
      index -> index
    end
  end

  ## Internal

  defp validate_alphabet_is_utf8_string(alphabet_str) do
    if is_binary(alphabet_str) and String.valid?(alphabet_str) do
      :ok
    else
      {:error, {:alphabet_is_not_an_utf8_string, alphabet_str}}
    end
  end

  defp validate_alphabet_graphemes_are_not_multibyte(alphabet_str) do
    alphabet_graphemes = String.graphemes(alphabet_str)

    case Enum.filter(alphabet_graphemes, &(byte_size(&1) !== 1)) do
      [] ->
        :ok

      multibyte_graphemes ->
        {:error, {:alphabet_contains_multibyte_graphemes, multibyte_graphemes}}
    end
  end

  defp validate_alphabet_length(alphabet_str) do
    if String.length(alphabet_str) < @min_alphabet_length do
      {:error, {:alphabet_is_too_small, min_length: @min_alphabet_length, alphabet: alphabet_str}}
    else
      :ok
    end
  end

  defp validate_alphabet_has_unique_chars(alphabet_str) do
    chars = :erlang.binary_to_list(alphabet_str)

    case chars -- Enum.uniq(chars) do
      [] ->
        :ok

      repeated_chars ->
        repeated_graphemes = for char <- repeated_chars, do: <<char>>
        {:error, {:alphabet_contains_repeated_graphemes, repeated_graphemes}}
    end
  end

  defp new_from_valid_str!(alphabet_str) do
    new_from_valid_str_recur(alphabet_str, _acc = [], _index_acc = 0)
  end

  defp new_from_valid_str_recur(<<byte, next::bytes>>, acc, index_acc) do
    acc = [{index_acc, byte} | acc]
    index_acc = index_acc + 1
    new_from_valid_str_recur(next, acc, index_acc)
  end

  defp new_from_valid_str_recur(<<>>, acc, _index_acc) do
    Map.new(acc)
  end

  defp map(alphabet, fun) do
    mapped_alphabet =
      alphabet
      |> Enum.map(fun)
      |> Map.new()

    # assert map_size(mapped_alphabet) === map_size(alphabet)
    mapped_alphabet
  end
end
