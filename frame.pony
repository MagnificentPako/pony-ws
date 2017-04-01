use "buffered"

class Frame
  let _final: Bool
  let _rsv: (Bool, Bool, Bool)
  let _opcode: Opcode
  let _use_mask: Bool
  let _payload_type: U8
  let _payload_size:  U64
  let _mask_key: (None | U32)
  let _data: String

  new create(final': Bool, opcode': Opcode, data': String) =>
    _final = final'
    _rsv = (false, false, false)
    _opcode = opcode'
    _use_mask = false
    _payload_type = if data'.size() <= 125 then
                      0 else if data'.size() <= 65535 then
                      1 else
                      2 end end
    _payload_size = data'.size().u64()
    _mask_key = None
    _data = data'

  fun get_data(): String => _data
  fun is_final(): Bool => _final

  /*new parse(data: Array[U8] iso): Frame =>
    let rb = Reader
    rb.append(consume data)
    try
      var fin_op = rb.u8()
      var mask_payloadlen = rb.u8()
      _final = if (((fin_op >> 7) and 0b00000001) == 1) then true else false end
      _rsv = (true, true, true)
      _opcode = OPTEXT
      _use_mask = if (((mask_payloadlen >> 7) and 0b00000001) == 1) then true else false end
      var payloadlen: U8 = (mask_payloadlen and 0b01111111)
      _payload_type: U8 = if payloadlen == 0b01111111 then
                        1 else if payloadlen == 0b01111110 then
                        2 else
                        0 end end
      _payload_size = match _payload_type
      | 0 => payloadlen.u64()
      | 1 => rb.u16_be().u64()
      | 2 => rb.u64_be().u64()
      else 0 end
      _mask_key = if _use_mask then rb.u32_be() else None end
      _data = String.from_array(rb.block(_payload_size.usize()))
    end*/

  fun build(): Array[ByteSeq] iso^ =>
    let writer = Writer
    writer.u8(0b10000001)
    if(_payload_type == 0) then
      writer.u8(0b10000110)
    else
      if(_payload_type == 1) then
        writer.u8(0b11111110)
        writer.u16_be(_payload_size.u16())
      else
        writer.u8(0b11111111)
        writer.u64_be(_payload_size)
      end
    end
    writer.u32_be(0)
    writer.write(_data)
    writer.done()
