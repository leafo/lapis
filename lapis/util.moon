
escape_pattern = do
  punct = "[%^$()%.%[%]*+%-?]"
  (str) -> (str\gsub punct, (p) -> "%"..p)

parse_query_string = do
  import C, P, S, Ct from require "lpeg"

  (str) ->
    chunk = C (P(1) - S("=&"))^1
    tuple = Ct(chunk * "=" * chunk + chunk)
    query = S"?#"^-1 * Ct tuple * (P"&" * tuple)^0

    with out = query\match str
      if out
        for tuple in *out
          out[tuple[1]] = tuple[2] or true

{ :escape_pattern, :parse_query_string }
