# [Sqids Elixir](https://sqids.org/elixir)

[![](https://img.shields.io/hexpm/v/sqids.svg?style=flat)](https://hex.pm/packages/sqids)
[![](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml)
[![Elixir Versions](https://img.shields.io/badge/Compatible%20with%20Elixir-1.12%20to%201.15-blue)](https://elixir-lang.org/)


[Sqids](https://sqids.org/elixir) (*pronounced "squids"*) for Elixir is a
library for generating YouTube-looking IDs from numbers. These IDs are short,
can be generated with a custom alphabet and are collision-free. [Read
more](https://sqids.org/faq).

This is what they look like in a URL:
```
https://example.com/LchsyE
https://example.com/Uxmq8Y
https://example.com/3CwlG7
```

## Why use them?

The main purpose is visual: you can use `Sqids` if you'd like to expose integer
identifiers in your software as alphanumeric strings.

### ✅ Use Cases

* **Link shortening**: default alphabet is safe to use in URLs, and common profanity is avoided
* **Event IDs**: collision-free ID generation
* **Database lookups**: by decoding IDs back into numbers

### ❌ Not Good For

* **Sensitive data**: this it not an encryption library
* **User IDs** generated in sequence, or equivalents: can be decoded, revealing
  user count and/or business growth

## Features:

* 🆔 Generate short IDs from non-negative integers
* 🤬 Avoid common profanity in generated IDs
* 🎲 IDs appear randomized when encoding incremental numbers
* 🧰 Decode IDs back into numbers
* 🔤 Generate IDs with a minimum length, making them more uniform
* 🔤 Generate IDs with a custom alphabet
* 👩‍💻 Available in [multiple programming languages](https://sqids.org)
* 👯‍♀️ Every equally configured implementation produces the same IDs
* 🍻 Small library with a permissive license

## 🚀 Getting started

The package can be installed by adding `sqids` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sqids, "~> 0.1"} # FIXME not uploaded yet
  ]
end
```

## 👩‍💻 Examples

### Default configuration

```elixir
iex> {:ok, sqids} = Sqids.new()
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "86Rf07"
iex> ^numbers = Sqids.decode!(sqids, id)
```

> **Note**
> 🚧 Because of the algorithm's design, **multiple IDs can decode back into the
> same sequence of numbers**. If it's important to your design that IDs are
> canonical, you have to re-encode decoded numbers and check that the
> generated ID matches.

### Custom configuration

Examples of custom configuration follow.

Note that different options can be used together for further customization.
Check the [API reference](https://hexdocs.pm/sqids/api-reference.html) for
details.

### Padding: generated IDs have a minimum length

```elixir
iex> {:ok, sqids} = Sqids.new(min_length: 10)
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "86Rf07xd4z" # instead of "86Rf07"
iex> ^numbers = Sqids.decode!(sqids, id)
```

(Older IDs, for ex. generated with a previous configuration in which padding
was not yet enforced or a different length was configured, can still be
decoded.)

### Using a custom alphabet

Generated IDs will be only contain characters from the chosen alphabet, which
is sensitive to both case and order.

```elixir
iex> {:ok, sqids} = Sqids.new(alphabet: "cdefhjkmnprtvwxy2345689")
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "wc9xdr"
iex> ^numbers = Sqids.decode!(sqids, id)
```

In order to decode IDs back, they need to be in the same alphabet.

For practical reasons, the standard limits alphabets to ASCII characters.

(Thanks to Ben Wheeler for his
suggestion for [a set of unambiguous-looking characters](https://stackoverflow.com/questions/11919708/set-of-unambiguous-looking-letters-numbers-for-user-input/58098360#58098360)
on Stack Overflow.)

### Profanity: preventing specific words within the generated IDs

Place [the ID generated with defaults](#default-configuration) in the
blocklist, replacing [the latter](https://github.com/sqids/sqids-blocklist/) in
the process.

```elixir
iex> {:ok, sqids} = Sqids.new(blocklist: ["86Rf07"])
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "se8ojk" # instead of "86Rf07"
iex> ^numbers = Sqids.decode!(sqids, id)
```

### Placing Sqids under your supervision tree for convenience

```elixir
iex> defmodule MyApp.Sqids do
iex>   use Sqids
iex> end
iex>
iex> defmodule MyApp.Application do
iex>   # ...
iex>   def start(_type, _args) do
iex>      children = [
iex>        MyApp.Sqids # or {MyApp.Sqids, opts}
iex>        # ...
iex>      ]
iex>
iex>      opts = [strategy: :one_for_one, name: Foobar.Supervisor]
iex>      Supervisor.start_link(children, opts)
iex>   end
iex> end
iex> {:ok, _} = MyApp.Application.start(:normal, [])
iex>
iex>
iex> numbers = [1, 2, 3]
iex> id = MyApp.Sqids.encode!(numbers)
iex> ^id = "86Rf07"
iex> ^numbers = MyApp.Sqids.decode!(id)
```

## 📝 License

[MIT](LICENSE)
