# StateSchema R6 Class

StateSchema R6 Class

StateSchema R6 Class

## Details

Defines typed fields with optional reducers for graph state management.
Use the
[`state_schema()`](https://ian-flores.github.io/orchestr/reference/state_schema.md)
constructor function.

## Active bindings

- `max_append`:

  Maximum number of items to keep for append reducers (read-only).

## Methods

### Public methods

- [`StateSchema$new()`](#method-StateSchema-new)

- [`StateSchema$validate()`](#method-StateSchema-validate)

- [`StateSchema$merge()`](#method-StateSchema-merge)

- [`StateSchema$field_names()`](#method-StateSchema-field_names)

- [`StateSchema$clone()`](#method-StateSchema-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new StateSchema

#### Usage

    StateSchema$new(..., .max_append = Inf)

#### Arguments

- `...`:

  Named type specifications. Each value is a string like
  `"append:list"`, `"any"`, `"logical"`, `"numeric"`, `"character"`,
  `"list"`, `"data.frame"`, or `"integer"`. The `"append:list"` form
  uses an append reducer for lists.

- `.max_append`:

  Maximum number of items to retain for append reducers. Defaults to
  `Inf` (no limit). When the limit is exceeded, the most recent items
  are kept.

------------------------------------------------------------------------

### Method `validate()`

Validate a set of updates against the schema

#### Usage

    StateSchema$validate(updates)

#### Arguments

- `updates`:

  Named list of values to validate

#### Returns

Invisible TRUE if valid; aborts on error

------------------------------------------------------------------------

### Method [`merge()`](https://rdrr.io/r/base/merge.html)

Merge updates into current state using reducers

#### Usage

    StateSchema$merge(current, updates)

#### Arguments

- `current`:

  Named list representing current state

- `updates`:

  Named list of updates

#### Returns

Merged state as a named list

------------------------------------------------------------------------

### Method `field_names()`

Get field names defined in this schema

#### Usage

    StateSchema$field_names()

#### Returns

Character vector of field names

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    StateSchema$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
