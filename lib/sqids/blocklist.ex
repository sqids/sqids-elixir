defmodule Sqids.Blocklist do
  @moduledoc false

  ## Types

  @enforce_keys [:min_word_length]

  defstruct min_word_length: nil, exact_matches: MapSet.new(), prefixes_and_suffixes: [], matches_anywhere: []

  @opaque t :: %__MODULE__{
            min_word_length: non_neg_integer,
            exact_matches: MapSet.t(String.t()),
            prefixes_and_suffixes: [String.t()],
            matches_anywhere: [String.t()]
          }

  @type new_error_reason ::
          {:blocklist_is_not_enumerable, term}
          | {:some_words_in_blocklist_are_not_utf8_strings, [term, ...]}

  ## API Functions

  @spec new(term, non_neg_integer, String.t()) :: {:ok, t()} | {:error, new_error_reason}
  def new(words, min_word_length, alphabet_str) do
    case validate_words(words) do
      :ok ->
        blocklist = new_for_valid_words(words, min_word_length, alphabet_str)
        {:ok, blocklist}

      {:error, _} = error ->
        error
    end
  end

  @spec blocked_id?(t(), String.t()) :: boolean()
  def blocked_id?(%__MODULE__{} = blocklist, id) do
    downcased_id = String.downcase(id)
    downcased_size = byte_size(downcased_id)

    cond do
      downcased_size < blocklist.min_word_length ->
        false

      downcased_size === blocklist.min_word_length ->
        MapSet.member?(blocklist.exact_matches, downcased_id)

      true ->
        String.contains?(downcased_id, blocklist.matches_anywhere) or
          String.starts_with?(downcased_id, blocklist.prefixes_and_suffixes) or
          String.ends_with?(downcased_id, blocklist.prefixes_and_suffixes)
    end
  end

  ## Internal Functions

  @spec validate_words(term) :: :ok | {:error, term}
  defp validate_words(words) do
    Enum.filter(words, &(not is_binary(&1) or not String.valid?(&1)))
  catch
    :error, %Protocol.UndefinedError{value: ^words} ->
      {:error, {:blocklist_is_not_enumerable, words}}
  else
    [] ->
      :ok

    invalid_words ->
      {:error, {:some_words_in_blocklist_are_not_utf8_strings, invalid_words}}
  end

  @spec new_for_valid_words(Sqids.enumerable(String.t()), non_neg_integer, String.t()) :: t()
  defp new_for_valid_words(words, min_word_length, alphabet_str) do
    alphabet_graphemes_downcased = alphabet_str |> String.downcase() |> String.graphemes() |> MapSet.new()
    sort_fun = fn word -> {String.length(word), word} end

    blocklist =
      words
      |> Enum.uniq()
      |> Enum.reduce(
        _acc0 = %__MODULE__{min_word_length: min_word_length},
        &maybe_add_blocklist_entry(&1, &2, alphabet_graphemes_downcased)
      )

    %{
      blocklist
      | prefixes_and_suffixes: Enum.sort_by(blocklist.prefixes_and_suffixes, sort_fun),
        matches_anywhere: Enum.sort_by(blocklist.matches_anywhere, sort_fun)
    }
  end

  @spec maybe_add_blocklist_entry(String.t(), t(), MapSet.t(String.grapheme())) :: t()
  defp maybe_add_blocklist_entry(word, blocklist, alphabet_graphemes_downcased) do
    downcased_word = String.downcase(word)
    downcased_length = String.length(downcased_word)

    cond do
      downcased_length < blocklist.min_word_length ->
        # Word is too short to include
        blocklist

      not (downcased_word |> String.graphemes() |> Enum.all?(&MapSet.member?(alphabet_graphemes_downcased, &1))) ->
        # Word contains characters that are not part of the alphabet
        blocklist

      downcased_length === blocklist.min_word_length ->
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
end
