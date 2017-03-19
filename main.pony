use "net"
use "net/ssl"
use "files"
use "encode/base64"
use "json"
use "buffered"

class MyTCPConnectionNotify is TCPConnectionNotify
  let _out: Env
  var responses: USize = 0

  new iso create(out: Env) =>
    _out = out

    fun ref connected(conn: TCPConnection ref) =>
      _out.out.print("CONNECTED")
      var sockKey: String = Base64.encode("1234567890abcdef")
      var handshake: Handshake = Handshake("gateway.discord.gg","/?v=6&encoding=json",sockKey)
      conn.set_nodelay(true)
      conn.set_keepalive(10)
      conn.write(handshake.build())

    fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
      if(responses == 1) then
        var wrapper: JsonDoc = JsonDoc
        var dat: JsonObject = JsonObject
        var main: JsonObject = JsonObject
        var props: JsonObject = JsonObject
        var shard: JsonArray = JsonArray
        shard.data.push(I64(0))
        shard.data.push(I64(1))
        main.data("shard") = shard
        props.data("$os") = "linux"
        props.data("$browser") = "Pony"
        props.data("$device") = "Pony"
        props.data("$referrer") = ""
        props.data("$referring_domain") = ""
        main.data("properties") = props
        main.data("token") = "MjgxMTYzNzcxNzU2NTQ0MDAx.C7BJ4w.GXQ1l1y5Xqc_dpYQv1R2rZ3yoLg"
        main.data("compress") = false
        main.data("large_threshold") = I64(250)
        dat.data("d") = main
        dat.data("op") = I64(2)
        wrapper.data = dat
        var identityFrame: Frame = Frame(true, OPTEXT, dat.string())
        conn.writev(identityFrame.build())
      end
      if responses != 0 then
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
          //_out.out.print(mask_payloadlen.string())
          _out.out.print("Final :" + (fin_op >> 7).string())
          _out.out.print("Type: " + payload_type.string())
          _out.out.print("Size: " + payload_size.string())
          _out.out.print("\n")
          var mask_key = if use_mask then rb.u32_be() else None end
          datt = String.from_array(rb.block(payload_size.usize()))
          var resFrame: Frame = Frame(final, opcode, datt)
          //_out.out.print(resFrame.get_data())
      end
    end

      responses = responses + 1
      false


actor Main
  new create(env: Env) =>


  /*  try
      var outFile: File = File(FilePath(env.root as AmbientAuth, "out.bin"))
      outFile.writev(identityFrame.build())
      outFile.sync()
    end*/


    let sslctx: (None | SSLContext) = try
      recover SSLContext
        .>set_client_verify(true)
        .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem"))
      end
    end

    try
      let ctx = sslctx as SSLContext
      let ssl = ctx.client()
      TCPConnection(env.root as AmbientAuth,
        SSLConnection(MyTCPConnectionNotify(env), consume ssl),
        "gateway.discord.gg",
        "443")

    end
