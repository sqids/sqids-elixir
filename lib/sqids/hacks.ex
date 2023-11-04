defmodule Sqids.Hacks do
  @moduledoc "Workarounds"
  @moduledoc since: "0.1.2"

  @doc """
  Function to work around Dialyzer warnings on violating
  type opacity when Sqids context is placed in a module attribute, since it
  becomes "hardcoded" from Dialyzer's point of view.
  """
  @spec dialyzed_ctx(term) :: Sqids.t()
  def dialyzed_ctx(sqids), do: Sqids.dialyzed_ctx(sqids)
end
