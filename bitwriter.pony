class BitWriter

  var _content: Array[U8] = _content.create(1)
  var _size: USize = 0
  var _offset: USize = 0

  fun ref done(): Array[U8] iso^ =>
    var byte_amount: USize = (_content.size() / 8)
    var output: Array[U8] iso = recover iso output.create(byte_amount) end
    if ((_content.size() % 8) != 0) then byte_amount = byte_amount + 1 end
    while _content.size() > 0 do
      var curr: Array[U8] = curr.create(8)
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr.push(_secure_pop(_content))
      curr = curr.reverse()
      output.push(_bits_to_byte(curr))
    end
    _content.reserve(1)
    _size = 0
    _offset = 0
    recover iso (consume output).reverse() end

  fun ref _check(size': USize) =>
    if (_content.size() - _offset) < size' then
      _content.undefined(_offset + size')
    end

fun ref u64(data: U64) =>
  _check(8)
  byte((data >> 56).u8())
  byte((data >> 48).u8())
  byte((data >> 40).u8())
  byte((data >> 32).u8())
  byte((data >> 24).u8())
  byte((data >> 16).u8())
  byte((data >> 8).u8())
  byte(data.u8())

fun ref u16(dat: U16) =>
  _check(2)
  byte((dat >> 8).u8())
  byte(dat.u8())

fun ref string(str: String) =>
  for byte' in str.array().values() do
    byte(byte')
  end

fun ref byte_array(bytes: Array[U8]) =>
  for byte' in bytes.values() do
    byte(byte')
  end

 fun ref byte(byte': U8) =>
     bit_array(_byte_to_bits(byte'))

  fun ref bit_array(bits: Array[U8]) =>
    _check(bits.size())
    for bit' in bits.values() do
      bit(bit')
    end

  /*fun ref bits_of_byte(byte': U8, amount: USize): Array[U8] iso^ =>
    var skip: USize = 8 - amount
    var ar: Array[U8] =  _byte_to_bits(byte')
    try while skip > 0 do
      ar.pop()
      skip = skip - 1
    end end
    var out: Array[U8] = out.create(USize(amount))
    var am: USize =  consume amount
      try while am > 0 do
        out.push(ar.pop())
        am = am - 1
      end
    end
    recover (consume out) end*/

  fun ref back() =>
    _offset = _offset -1

  fun ref bit(bit': U8) =>
    try
      _check(1)
      _content(_offset) = (bit' and 0b00000001) //So it actually is just one bit
      _offset = _offset + 1
      _size = _size + 1
    end

  fun _byte_to_bits(byte': U8): Array[U8] =>
    var bits: Array[U8] = bits.create(8)
    var mask: U8 = 0b00000001
    bits.push(((byte' >> 7) and mask))
    bits.push(((byte' >> 6) and mask))
    bits.push(((byte' >> 5) and mask))
    bits.push(((byte' >> 4) and mask))
    bits.push(((byte' >> 3) and mask))
    bits.push(((byte' >> 2) and mask))
    bits.push(((byte' >> 1) and mask))
    bits.push((byte'        and mask))
    bits

    fun _bits_to_byte(bits: Array[U8]): U8 =>
      var res: U8 = 0
      try
        res = (bits.pop())      or
              (bits.pop() << 1) or
              (bits.pop() << 2) or
              (bits.pop() << 3) or
              (bits.pop() << 4) or
              (bits.pop() << 5) or
              (bits.pop() << 6) or
              (bits.pop() << 7)
      end
      res

  fun _secure_pop(ar: Array[U8]): U8 =>
    var p: U8 = 0
    try
      var popped: (None | U8) = ar.pop()
      p = match popped
      | None => 0
      else popped as U8 end
    end
    p
