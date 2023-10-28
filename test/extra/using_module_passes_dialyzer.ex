defmodule SqidsTest.Extra.UsingModulePassesDialyzer do
  @moduledoc false
  use Sqids

  @impl true
  def child_spec, do: child_spec([])
end
