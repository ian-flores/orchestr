# Merge state without a schema

Shallow overwrite merge for schema-less state. Each key in `updates`
replaces the corresponding key in `current`.

## Usage

``` r
merge_state_plain(current, updates)
```

## Arguments

- current:

  Named list of current state

- updates:

  Named list of updates

## Value

Merged named list
