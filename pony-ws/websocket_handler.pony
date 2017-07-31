use "net"
use "buffered"
use "encode/base64"
use "debug"

primitive HTTPHeader
primitive WebSocket
type ParserState is (HTTPHeader | WebSocket)

class WebsocketHandler is TCPConnectionNotify

  let _host: String
  let _target: String
  var _connected: Bool = false
  var _current_content: String = ""
  var _current_fragments: USize = 0
  var _current_size: USize = 0
  var _notify: WebsocketNotify
  var _writing: Bool = false
  var _state: ParserState = HTTPHeader
  var _http_buffer: String = ""

  var _in_header: Bool = true
  var _base_header: Bool = true
  var _expected_size: USize = -1

  var _payload_len: U8 = -1
  var _payload_type: PayloadType = PayloadSmall
  var _payload_size: U64 = -1
  var _data: String = ""
  var _final: Bool = false

  new iso create(host': String, target': String, notify': WebsocketNotify iso) =>
    _host = host'
    _target = target'
    _notify = consume notify'

  fun ref connected(conn: TCPConnection ref) =>
    var sockKey: String = Base64.encode("1234567890abcdef")
    var handshake: Handshake = Handshake(_host,_target,sockKey)
    conn.write(handshake.build())
    conn.expect(1)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if(_state == HTTPHeader) then
        let rb: Reader = Reader
        _http_buffer.append(rb.u8())
        try
            _http_buffer.find("\r\n\r\n")
            _state = WebSocket
            _connected = true
            conn.expect(2)
            _in_header = true
            _base_header = true
        else
            conn.expect(1)
        end
    else
         _writing = false
        let rb: Reader = Reader
        rb.append(consume data)
        if (_in_header and _base_header) then
        try
            var fin_op: U8 = rb.u8()
            var mask_payloadlen: U8 = rb.u8()
            _final = if (((fin_op >> 7) and 0b00000001) == 1) then true else false end
            var use_mask: Bool = if (((mask_payloadlen >> 7) and 0b00000001) == 1) then true else false end
            _payload_len = (mask_payloadlen and 0b01111111)
            _payload_type = if _payload_len == 0b01111111 then
                            PayloadLarge elseif _payload_len == 0b01111110 then
                            PayloadMedium else
                            PayloadSmall end
            var mask_key = if use_mask then rb.u32_be() else None end
            if _payload_type == PayloadSmall then
            _expected_size = _payload_len.usize()
            _payload_size = _expected_size.u64()
            _in_header = false
            _base_header = false
            conn.expect(_payload_len.usize())
            elseif _payload_type == PayloadMedium then
            _base_header = false
            _expected_size = 2
            conn.expect(2)
            else
            _base_header = false
            _expected_size = 4
            conn.expect(4)
            end
        end
        elseif (_in_header and (not _base_header)) then
        //Basic header is done. Handling payload len now
        try
            _payload_size = match _payload_type
            | PayloadMedium => rb.u16_be().u64()
            | PayloadLarge => rb.u64_be().u64()
            else 0 end
            conn.expect(_payload_size.usize())
        end
        _in_header = false
        _base_header = false
        else
            //Load data
            _in_header = true
            _base_header = true
            try
                _data = String.from_array(rb.block(_payload_size.usize()))
                _current_content = _current_content + _data
                if(_final) then
                    _notify.received(conn, _current_content)
                    _data = ""
                    _current_content = ""
                end
                conn.expect(2)
            end
        end
    end
   
    true

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    if(_writing) then return data end
    if(_connected) then
      _writing = true
      conn.writev(Frame.text(
        match data
        | let data': String    => data'
        | let data': Array[U8] val => String.from_array(data')
        else
          ""
        end
        ).build())
      ""
    else
      return data
    end
