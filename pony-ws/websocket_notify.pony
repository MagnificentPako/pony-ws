use "net"

interface WebsocketNotify

  fun ref received(conn: TCPConnection ref, data: String)
