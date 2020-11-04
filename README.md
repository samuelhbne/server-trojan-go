# server-trojan-go

Yet another unofficial [Trojan-go](https://github.com/p4gefau1t/trojan-go) server container with x86 and arm/arm64 (Raspberry Pi) support.

![docker-build](https://github.com/samuelhbne/server-trojan-go/workflows/docker-build/badge.svg)

## [Optional] How to build server-trojan-go docker image

```shell
$ git clone https://github.com/samuelhbne/server-trojan-go.git
$ cd server-trojan-go
$ docker build -t samuelhbne/server-trojan-go:amd64 -f Dockerfile.amd64 .
...
```

### NOTE1

- Please replace "amd64" with the arch match the current box accordingly. For example: "arm64" for AWS ARM64 platform like A1 and t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.

## How to start server-trojan-go container

```shell
$ docker run --rm -it samuelhbne/server-trojan-go:amd64
server-trojan-go -d|--domain <domain-name> -w|--password <password> [-p|--port <port-num>] [-f|--fake <fake-domain>] [-k|--hook <hook-url>] [--wp <websocket-path>] [--sp <shadowsocks-pass>] [--sm <shadowsocks-method>]
    -d|--domain <domain-name> Trojan-go server domain name
    -w|--password <password>  Password for Trojan-go service access
    -p|--port <port-num>      [Optional] Port number for incoming Trojan-go connection, default 443
    -f|--fake <fake-domain>   [Optional] Fake domain name when access Trojan-go without correct password
    -k|--hook <hook-url>      [Optional] URL to be hit before server execution, for DDNS update or notification
    -c|--china                [Optional] Enable China-site access block to avoid being detected, default disable
    --wp <websocket-path>     [Optional] Enable websocket with websocket-path setting, e.g. '/ws'. default disable
    --sp <shadowsocks-pass>   [Optional] Enable Shadowsocks AEAD with given password, default disable
    --sm <shadowsocks-method> [Optional] Encryption method applied in Shadowsocks AEAD layer, default AES-128-GCM
$ docker run --name server-trojan-go -p 80:80 -p 8443:443 -d samuelhbne/server-trojan-go:amd64 -d my-domain.com -w my-secret
...
$
```

### NOTE2

- Please replace "amd64" with the arch match the current box accordingly. For example: "arm64" for AWS ARM64 platform like A1 and t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.
- Please ensure TCP port 80 of the current server is reachable, or TLS cert acquisition will fail otherwise.
- Please replace 8443 with the TCP port number you want to listen for Trojan-go service.
- Please replace "my-domain.com" and "my-secret" above with your FULL domain-name and Trojan-go service access password accordingly.
- You can optionally assign a HOOK-URL to update the DDNS domain-name pointing to the current server public IP address.
- Alternatively, server-trojan-go assumes you've ALREADY set the domain-name pointed to the current server public IP address. server-trojan-go may fail as unable to obtian Letsencrypt cert for the domain-name you set otherwise .
- You may reach the limitation of 10 times renewal a day applied by Letsencrypt soon if you remove and restart server-trojan-go container too frequent.

## How to verify if server-trojan-go is running properly

Try to connect the server from trojan compatible mobile app like [Igniter](https://github.com/trojan-gfw/igniter) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the domain-name and password set above. Or verify it from Ubuntu / Debian / Raspbian client host follow the instructions below.

### Please run the following instructions from Ubuntu / Debian / Raspbian client host for verifying

```shell
$ docker run --rm -it samuelhbne/proxy-trojan-go:amd64
proxy-trojan-go -d|--domain <trojan-go-domain> -w|--password <password> [-p|--port <port-number>] [-c|--china] [--wp <websocket-path>] [--sp <shadowsocks-pass>] [--sm <shadowsocks-method>]
    -d|--domain <trojan-go-domain>  Trojan-go server domain name
    -w|--password <password>        Password for Trojan-go server access
    -p|--port <port-num>            [Optional] Port number for Trojan-go server connection, default 443
    -m|--mux                        [Optional] Enable Trojan-go mux (incompatible with original Trojan server), default disable
    -c|--china                      [Optional] Enable China-site access without proxy, default disable
    --wp <websocket-path>           [Optional] Enable websocket with websocket-path setting, e.g. '/ws'. default disable
    --sp <shadowsocks-pass>         [Optional] Enable Shadowsocks AEAD with given password, default disable
    --sm <shadowsocks-method>       [Optional] Encryption method applied in Shadowsocks AEAD layer, default AES-128-GCM
$ docker run --name proxy-trojan-go -p 1080:1080 -p 65353:53/udp -p 8123:8123 -d samuelhbne/proxy-trojan-go:amd64 -d my-domain.com -p 8443 -w my-secret
...

$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78
```

### NOTE4

- First we ran proxy-trojan-go as SOCKS5 proxy that tunneling traffic through your trojan-go server.
- Then launching curl with client-IP address query through the proxy.
- This query was sent through your server with server-trojan-go running.
- You should get the public IP address of your server with server-trojan-go running if all good.
- Please have a look over the sibling project [proxy-trojan-go](https://github.com/samuelhbne/proxy-trojan-go) for more details.

## How to stop and remove the running container

```shell
$ docker stop server-trojan-go;
...
$ docker rm server-trojan-go
...
$
```
