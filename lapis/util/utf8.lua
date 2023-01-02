local P, R, S, C
do
  local _obj_0 = require("lpeg")
  P, R, S, C = _obj_0.P, _obj_0.R, _obj_0.S, _obj_0.C
end
local cont = R("\128\191")
local multibyte_character = R("\194\223") * cont + R("\224\239") * cont * cont + R("\240\244") * cont * cont * cont
local whitespace = S("\13\32\10\11\12\9") + P("\239\187\191") + P("\194") * S("\133\160") + P("\225") * (P("\154\128") + P("\160\142")) + P("\226") * (P("\128") * S("\131\135\139\128\132\136\140\175\129\133\168\141\130\134\169\138\137") + P("\129") * S("\159\160")) + P("\227\128\128")
local direction_mark = P("\226\128") * S("\142\143\170\171\172\173\174") + P("\216\156")
local unused_direction_mark = direction_mark * #((whitespace + direction_mark) ^ -1 * -1)
whitespace = whitespace + unused_direction_mark
local printable_character = S("\r\n\t") + R("\032\126") + multibyte_character
local trim = whitespace ^ 0 * C((whitespace ^ 0 * (1 - whitespace) ^ 1) ^ 0)
local string_length
string_length = function(str)
  local len = 0
  local pos = 1
  while true do
    local res = printable_character:match(str, pos)
    if not (res) then
      break
    end
    pos = res
    len = len + 1
  end
  if not (pos > #str) then
    return nil, "invalid string"
  end
  return len
end
return {
  multibyte_character = multibyte_character,
  printable_character = printable_character,
  whitespace = whitespace,
  direction_mark = direction_mark,
  trim = trim,
  string_length = string_length
}
