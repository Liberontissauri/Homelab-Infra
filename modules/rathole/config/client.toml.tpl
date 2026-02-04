[client]
remote_addr = "${vps_ip}:2333"
default_token = "${rathole_token}"
heartbeat_timeout = 40
retry_interval = 1

[client.transport]
type = "tcp"

[client.services.minecraft]
token = "${rathole_token}"
local_addr = "minecraft:25565"
type = "tcp"

[client.services.rcon]
token = "${rathole_token}"
local_addr = "minecraft:25575"
type = "tcp"

