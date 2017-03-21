use "json"
use "net"
use "time"
use "debug"
use "files"
use "net/ssl"

class TestWSNotify is WebsocketNotify

  let _env: Env
  var _identified: Bool = false
  var _got_heartbeat: Bool = false
  var _heartbeat_d: I64 = -1

  new iso create(env': Env) =>
    _env = env'

  fun _get_d(): I64 => _heartbeat_d

  fun ref received(conn: TCPConnection, data: String) =>
    _env.out.print("GOT: " + data + "\n")
    var data': JsonDoc = JsonDoc
    try
      data'.parse(data)
    else
      Debug("DAMN SON, YOU BROKE THE DAMN THING")
      return None
    end
    try
      if (((data'.data as JsonObject).data("op") as I64) == 0 ) then
        _heartbeat_d = ((data'.data as JsonObject).data("s") as I64)
      end
    end
    if(not _got_heartbeat) then
      try
        if( ((data'.data as JsonObject).data("op") as I64) == 10 ) then
          let timers = Timers
          let timer = Timer(recover object is TimerNotify
            let _conn: TCPConnection = conn
            let _parent: TestWSNotify ref = this
            fun ref apply(timer: Timer, count: U64): Bool =>
              var wrapper: JsonDoc = JsonDoc
              var main: JsonObject = JsonObject
              main.data("op") = I64(1)
              main.data("d") = if (_parent._get_d() != -1) then _parent._get_d() else None end
              Debug(main.string())
              true
          end end, 0, (((data'.data as JsonObject).data("d") as JsonObject).data("heartbeat_interval") as I64) * 1_000_000)
        end
      end
    end
    if(not _identified) then
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
      main.data("token") = "MjgxMTYzNzcxNzU2NTQ0MDAx.C7LJAQ.BnKWvIAEYsY65WMoaI9bGFK5nYM"
      main.data("compress") = false
      main.data("large_threshold") = I64(250)
      dat.data("d") = main
      dat.data("op") = I64(2)
      wrapper.data = dat
      conn.write(wrapper.string())
      _identified = true
    end

actor Main
  new create(env: Env) =>

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
        SSLConnection(WebsocketHandler("gateway.discord.gg","/?v=6&encoding=json",TestWSNotify(env)), consume ssl),
        "gateway.discord.gg",
        "443")
    end
