use "net"
use "buffered"

primitive OpContinuation
primitive OpText
primitive OpBinary
primitive OpClose
primitive OpPing
primitive OpPong

type OpCode is (OpContinuation |
                OpText         |
                OpBinary       |
                OpClose        |
                OpPing         |
                OpPong         )

primitive PayloadSmall
primitive PayloadMedium
primitive PayloadLarge

type PayloadType is (PayloadSmall | PayloadMedium | PayloadLarge)

class trn Frame
    """
    A class representing a single websocket frame which can be sent from/to a server.
    """
    var _final: Bool = false
    var _rsv: (Bool, Bool, Bool) = (false, false, false)
    var _opcode: OpCode = OpText
    var _use_mask: Bool = true
    var _payload_type: PayloadType = PayloadSmall
    var _payload_size:  USize = 0
    var _mask_key: (None | U32) = None
    var _data: String = ""

    new iso text(data: String = "") =>
        """
        Creates a new text frame.
        """
        _data = data
        _opcode = OpText
        _use_mask = true
        _mask_key = 0
        _payload_type = if data.size() <= 125 then
                    PayloadSmall else if data.size() <= 65535 then
                    PayloadMedium else
                    PayloadLarge end end
        _final = true
    
    fun ref set_mask_key(key: (None | U32)) =>
        """
        Set the mask key.
        """
        _mask_key = key
    
    fun get_data(): String => _data

    fun build(): Array[ByteSeq] iso^ =>
        let writer = Writer
        writer.u8(0b10000001)
        if(_payload_type == PayloadSmall) then
        writer.u8(0b10000110)
        else
            if(_payload_type == PayloadMedium) then
                writer.u8(0b11111110)
                writer.u16_be(_payload_size.u16())
            else
                writer.u8(0b11111111)
                writer.u64_be(_payload_size)
            end
        end
        if(_use_mask) then
            writer.u32_be(_mask_key)
        end
        writer.write(_data)
        writer.done()