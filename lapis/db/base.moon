
NULL = {}
raw = (val) -> {"raw", tostring(val)}
is_raw = (val) ->
  type(val) == "table" and val[1] == "raw" and val[2]

TRUE = raw"TRUE"
FALSE = raw"FALSE"


{
  :NULL, :TRUE, :FALSE, :raw, :is_raw
}
