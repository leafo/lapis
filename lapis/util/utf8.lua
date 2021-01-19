local P, R, S
do
  local _obj_0 = require("lpeg")
  P, R, S = _obj_0.P, _obj_0.R, _obj_0.S
end
local cont = R("\128\191")
local multibyte_character = R("\194\223") * cont + R("\224\239") * cont * cont + R("\240\244") * cont * cont * cont
local whitespace = S("\13\32\10\11\12\9") + P("\239\187\191") + P("\194") * S("\133\160") + P("\225") * (P("\154\128") + P("\160\142")) + P("\226") * (P("\128") * S("\131\135\139\128\132\136\140\175\129\133\168\141\130\134\169\138\137") + P("\129") * S("\159\160")) + P("\227\128\128")
local printable_character = S("\r\n\t") + R("\032\126") + multibyte_character
return {
  multibyte_character = multibyte_character,
  printable_character = printable_character,
  whitespace = whitespace
}
