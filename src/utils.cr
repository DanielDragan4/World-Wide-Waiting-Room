require "big"

def force_big_int (v : String | Float64 | Float32 | Int32 | Int64 | BigInt | BigFloat) : BigInt
  BigInt.new (BigFloat.new v)
end
