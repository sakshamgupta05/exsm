# Exsm

[![Build Status](https://travis-ci.org/sakshamgupta05/exsm.svg?branch=master)](https://travis-ci.org/sakshamgupta05/exsm)
[![codecov](https://codecov.io/gh/sakshamgupta05/exsm/branch/master/graph/badge.svg?token=)](https://codecov.io/gh/sakshamgupta05/exsm)
[![hex.pm version](https://img.shields.io/hexpm/v/exsm.svg)](https://hex.pm/packages/exsm)
[![hex.pm downloads](https://img.shields.io/hexpm/dt/exsm.svg)](https://hex.pm/packages/exsm)

Exsm is a thin State Machine library for Elixir that integrates with
Phoenix out of the box.

It's just a small layer that provides a DSL for declaring states
and having callbacks for structs.

Don't forget to check the [Exsm Docs](https://hexdocs.pm/exsm)

- [Installation](#installation)
- [Declaring States](#declaring-states)
  - [State Machine Module](#state-machine-module)
  - [Supported Declaration Types](#supported-declaration-types)
  - [Wildcards](#wildcards)
- [Changing States](#changing-states)
- [Validate Transition](#validate-transition)
- [Callbacks](#callbacks)
  - [Before Callback](#before-callback)
  - [Persist State](#persist-state)
  - [Logging Transitions](#logging-transitions)
  - [After Callback](#after-callback)
- [Credits](#credits)

## Installation

The package can be installed by adding `exsm` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exsm, "~> 0.3"}
  ]
end
```

Create a field `state` (or a name of your choice to be defined later) for the
module you want to have a state machine, make sure you have declared it as part
of you `defstruct`, or if it is a Phoenix model make sure you add it to the `schema`,
as a `string`,  and to the `changeset/2`:

```elixir
defmodule YourProject.User do
  schema "users" do
    # ...
    field :state, :string
    # ...
  end

  def changeset(%User{} = user, attrs) do
    #...
    |> cast(attrs, [:state])
    #...
  end
end
```

## Declaring States

Declare the states as an argument when importing `Exsm` on the module that
will control your states transitions.


### State Machine Module

It's strongly recommended that you create a new module for your State Machine
logic. So let's say you want to add it to your `User` model, you should create a
`UserStateMachine` module to hold your State Machine logic.

Exsm expects a `Keyword` as argument with the keys `field`, `states` and `transitions`.

- `field`: An atom of your state field name (defaults to `state`)
- `states`: A List of Strings representing each state.
- `transitions`: A Map for each state and it allowed next state(s).

#### Example

```elixir
defmodule YourProject.UserStateMachine do
  use Exsm,
    # This is a way to define a custom field, if not defined
    # it will expect the default `state` field in the struct
    field: :custom_state_name,
    # The first state declared will be considered
    # the initial state.
    states: ["created", "partial", "complete", "canceled"],
    transitions: %{
      "created" =>  ["partial", "complete"],
      "partial" => "completed",
      "*" => "canceled"
    }
end
```

### Supported Declaration Types

#### One - One
Define transition from one state to another state.
```elixir
"a" => "b"
```
#### One - Many
Define transition from one state to multiple states.
```elixir
"a" => ["b", "c"]
```
#### Many - One
Define transition from Multiple states to a single state.
```elixir
["a", "b"] => "c"
```
#### Many - Many
Define transition from multiple states to multiple other states.
```elixir
# This is equivalent to "a" => ["c", "d", "e"] and "b" => ["c", "d", "e"]
["a", "b"] => ["c", "d", "e"]
```

### Wildcards

The wildcards can be used to easily define transition from/to all defined
states to a set of states.

- **`"*"`**: This wildcard can be used when you want to define a transtition from all
defined states to a state or a subset including all self transitions.

- **`"^"`**: It serves a similar purpose as `"*"` but excludes all self transitions.

#### Example

```elixir
states: ["a", "b", "c", "d", "e"],
transitions: %{
  "*" => "b",         # ["a", "b", "c", "d", "e"] =>  "b"
  ["a", "b"] => "*",  # ["a", "b"] => ["a", "b", "c", "d", "e"]
  "^" => ["c", "d"],  # ["a", "b", "d", "e"] =>  "c" and ["a", "b", "c", "e"] =>  "d"
  "e" => "^"          # "e" => ["a", "b", "c", "d"]
}
```

## Changing States

To transit a struct into another state, you just need to
call `Exsm.transition_to/3`.

### `Exsm.transition_to/3`
It takes three arguments:

- `struct`: The `struct` you want to transit to another state.
- `state_machine_module`: The module that holds the state machine logic, where Exsm as imported.
- `next_event`: `string` of the next state you want the struct to transition to.

**Before and after callbacks will be checked automatically.**

```elixir
Exsm.transition_to(your_struct, YourStateMachine, "next_state")
# {:ok, updated_struct}
```

### Example:

```elixir
user = Accounts.get_user!(1)
Exsm.transition_to(user, UserStateMachine, "complete")
```

## Validate Transition

If you want to check if a transition is valid without actually performing
the transition, you can do so using `Exsm.valid_transition?/3`

### `Exsm.valid_transition?/3`
It takes three arguments:

- `struct`: The `struct` you want to transit to another state.
- `state_machine_module`: The module that holds the state machine logic, where Exsm as imported.
- `next_event`: `string` of the next state you want the struct to transition to.

```elixir
Exsm.valid_transition?(your_struct, YourStateMachine, "next_state")
# true/false
```

### Example:

```elixir
user = Accounts.get_user!(1)
Exsm.valid_transition?(user, UserStateMachine, "complete")
```

## Callbacks

Callbacks are useful for defining side effectd during state transitions.
Additionally `before_transition/3` can be used as a guard to stop the transition
from occuring if a certain pre-condition or a side effect fails.

Callbacks are executed in the following order during a transition
1. `before_transition/3`
2. `persist/3`
3. `log_transition/3`
4. `after_transition/3`

### Before callback

Before callback is useful for executing some side effects before the transition
occurs as well as guarding the transition from happening either due to some
pre-defined condition or side effect failing. Struct can also be modified here and the
updated struct will be passed on to the other callbacks.

Create before callback by adding signatures of the `before_transition/3`
function, it will receive three arguments, the `struct`, a `prev_state` from where
the transition started and a `next_state` where it will transit to. Use the second
and the third arguments to pattern match the previous and next states.

`before_transition/3` should return one of the following values:
  - `{:error, "cause"}`: Transition won't be allowed in this case.
  - `{:ok, struct}`: Transition will be allowed and the struct will be passed on to other callbacks

#### Example:

```elixir
defmodule YourProject.UserStateMachine do
  use Exsm,
    states: ["created", "complete"],
    transitions: %{"created" => "complete"}

  # Before callback for transition "created" to "complete"
  def before_callback(struct, "created", "complete") do
    if Map.get(struct, :missing_fields) == true do
      {:error, "There are missing fields"}
    else
      struct = preform_operation(struct)
      {:ok, struct}
    end
  end
end
```

When trying to transition an struct that is blocked by its before callback you will
have the following return:

```elixir
blocked_struct = %TestStruct{state: "created", missing_fields: true}
Exsm.transition_to(blocked_struct, TestStateMachineWithGuard, "completed")

# {:error, "There are missing fields"}
```

### Persist State
To persist the struct and the state transition automatically, instead of having
Exsm changing the struct itself, you can declare a `persist/3` function on
the state machine module.

It will receive the unchanged `struct` as the first argument, the `prev_state`
as second and the `next_state` as the third one, after every state transition.
That will be called between the before and after transition callbacks.

**`persist/3` should always return the updated struct.**

#### Example:

```elixir
defmodule YourProject.UserStateMachine do
  alias YourProject.Accounts

  use Exsm,
    states: ["created", "complete"],
    transitions: %{"created" => "complete"}

  def persist(struct, _prev_state, next_state) do
    # Updating a user on the database with the new state.
    {:ok, user} = Accounts.update_user(struct, %{state: next_state})
    user
  end
end
```

### Logging Transitions
To log/persist the transitions itself Exsm provides a callback
`log_transitions/3` that will be called on every transition.

It will receive the unchanged `struct` as the first argument, the `prev_state`
 as second and the `next state` as the third one, after every state transition.
This function will be called between the before and after transition callbacks
and after the persist function.

**`log_transition/3` should always return the updated struct.**

#### Example:

```elixir
defmodule YourProject.UserStateMachine do
  alias YourProject.Accounts

  use Exsm,
    states: ["created", "complete"],
    transitions: %{"created" => "complete"}

  def log_transition(struct, _prev_state, _next_state) do
    # Log transition here, save on the DB or whatever.
    # ...
    # Return the struct.
    struct
  end
end
```

### After callback

You can also use after callback to handle desired side effects and
reactions to a specific state transition.

You can just declare `after_transition/3`, pattern matching the
desired state you want to.

**Make sure After callbacks should return the struct.**

```elixir
# callbacks should always return the struct.
def after_transition(struct, "prev_state", "next_state"), do: struct
```

#### Example:

```elixir
defmodule YourProject.UserStateMachine do
  use Exsm,
    states: ["created", "partial", "complete"],
    transitions: %{
      "created" =>  ["partial", "complete"],
      "partial" => "completed"
    }

    def after_transition(struct, _prev_state, "completed") do
      # ... overall desired side effects
      struct
    end
end
```

## Credits

* [Machinery](https://github.com/joaomdmoura/machinery) - State machine thin layer for structs
