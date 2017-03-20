use "net"

interface WebsocketNotify

  fun received(conn: TCPConnection ref, data: String)
