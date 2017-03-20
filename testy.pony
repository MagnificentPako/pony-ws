use "net"
use "json"
use "files"
use "net/ssl"

class TestWSNotify is WebsocketNotify

  let _env: Env
  new create(env': Env) =>
    _env = env'

  fun received(conn: TCPConnection, data: String) =>
    _env.out.print(data)

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
