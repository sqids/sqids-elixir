# Migration guide

Whenever there's an interface breaking change (a change in the project's major version),
required migration instructions will be detailed in this file.

## From [0.1.x] to [0.2.x]

### Update

If you use supervised Sqids and its entry under the Supervisor is just the module's name, change it:
```elixir
# before
children = [
  MyApp.Sqids
]

# after
children = [
  MyApp.Sqids.child_spec()
]

```

And then update your Sqids-using module to either clear custom options that never had any effect (safest)
or keep them if you want them to start working (BREAKS COMPATIBILITY WITH EXISTING IDs).
```elixir
defmodule MyApp.Sqids do
    use Sqids

    @impl true
    def child_spec do
        child_spec([
            # * either clear custom options (safe)
            # * or keep them so they start working (BREAKS COMPATIBILITY)
        ])
    end
```
