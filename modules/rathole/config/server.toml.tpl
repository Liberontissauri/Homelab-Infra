[server]
bind_addr = "0.0.0.0:2333"
default_token = "${rathole_token}"
heartbeat_interval = 30

[server.transport]
type = "tcp"

[server.services.minecraft]
token = "${rathole_token}"
bind_addr = "0.0.0.0:25565"
type = "tcp"

[server.services.rcon]
token = "${rathole_token}"
bind_addr = "0.0.0.0:25575"
type = "tcp"

