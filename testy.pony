use "json"
use "net"
use "debug"
use "files"
use "net/ssl"

class TestWSNotify is WebsocketNotify

  let _env: Env
  var _identified: Bool = false

  new iso create(env': Env) =>
    _env = env'

  fun ref received(conn: TCPConnection, data: String) =>
    //_env.out.print(data)
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
      main.data("token") = ""
      main.data("compress") = false
      main.data("large_threshold") = I64(250)
      dat.data("d") = main
      dat.data("op") = I64(2)
      wrapper.data = dat
      //_env.out.print(dat.string(" ", true))
      conn.write(wrapper.string())
      //conn.write("hi")
      _env.out.print("SENT IDENTIFICATION")
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
