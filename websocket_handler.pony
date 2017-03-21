use "net"
use "buffered"
use "encode/base64"

class WebsocketHandler is TCPConnectionNotify

  let _host: String
  let _target: String
  var _connected: Bool = false
  var _current_content: String = ""
  var _current_fragments: USize = 0
  var _current_size: USize = 0
  var _notify: WebsocketNotify
  var _env: Env

  new iso create(env': Env, host': String, target': String, notify': WebsocketNotify iso) =>
    _host = host'
    _target = target'
    _notify = consume notify'
    _env = env'

  fun ref connected(conn: TCPConnection ref) =>
    var sockKey: String = Base64.encode("1234567890abcdef")
    var handshake: Handshake = Handshake(_host,_target,sockKey)
    conn.write(handshake.build())

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if(not _connected) then
      _connected = true //"swallows" the first response, which is supposed to be
                        //a HTTP Upgrade response
    else
      let rb: Reader = Reader
      rb.append(consume data)
      var final: Bool = true
      var opcode: Opcode = OPCLOSE
      var datt: String = ""
      try
        var fin_op: U8 = rb.u8()
        var mask_payloadlen: U8 = rb.u8()
        final = if (((fin_op >> 7) and 0b00000001) == 1) then true else false end
        opcode = OPTEXT
        var use_mask: Bool = if (((mask_payloadlen >> 7) and 0b00000001) == 1) then true else false end
        var payloadlen: U8 = (mask_payloadlen and 0b01111111)
        var payload_type: U8 = if payloadlen == 0b01111111 then
                          1 else if payloadlen == 0b01111110 then
                          2 else
                          0 end end
        var payload_size: U64 = match payload_type
        | 0 => payloadlen.u64()
        | 1 => rb.u16_be().u64()
        | 2 => rb.u64_be().u64()
        else 0 end
        var mask_key = if use_mask then rb.u32_be() else None end
        datt = String.from_array(rb.block(payload_size.usize()))
        if(not final) then
          _current_content = _current_content + datt
        else
          _current_content = _current_content + datt
          _notify.received(conn, _current_content)
          _current_content = ""
        end
      end
    end
    true

  fun sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    if(_connected) then
      _env.out.write(".")
      conn.writev(Frame(
        true, OPTEXT, match data
        | let data': String    => data'
        | let data': Array[U8] val => String.from_array(data')
        else
          ""
        end
        ).build())
      return ""
    else
      return data
    end
