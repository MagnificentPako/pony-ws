use "net"

class Handshake
  var _url: String
  var _target: String
  var _key: String
  let _proto: String = "HTTP/1.1"

  new create(url': String, target': String, key': String) =>
    _url = url'
    _target = target'
    _key = key'

  fun build(): String =>
    ("GET "+ _target +" "+ _proto +"\r\n" +
     "Host: "+ _url +"\r\n" +
     "Upgrade: websocket\r\n" +
     "Connection: Upgrade\r\n"+
     "Sec-WebSocket-Key: "+ _key +"\r\n" +
     "Sec-WebSocket-Version: 13\r\n\r\n")
