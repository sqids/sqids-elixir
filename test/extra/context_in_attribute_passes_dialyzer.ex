defmodule SqidsTest.Extra.ContextInAttributePassesDialyzer do
  @moduledoc false

  import Sqids.Hacks, only: [dialyzed_ctx: 1]

  @context Sqids.new!()

  @spec encode!([non_neg_integer]) :: String.t()
  def encode!(numbers), do: Sqids.encode!(dialyzed_ctx(@context), numbers)

  @spec decode!(String.t()) :: [non_neg_integer]
  def decode!(id), do: Sqids.decode!(dialyzed_ctx(@context), id)
end
