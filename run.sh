#!/bin/bash

usage() {
	echo "server-trojan-go -d|--domain <domain-name> -w|--password <password> [-p|--port <port-num>] [-f|--fake <fake-domain>] [-k|--hook <hook-url>] [--wp <websocket-path>] [--sp <shadowsocks-pass>] [--sm <shadowsocks-method>] [--share-cert <cert-path>]"
	echo "    -d|--domain <domain-name> Trojan-go server domain name"
	echo "    -w|--password <password>  Password for Trojan-go service access"
	echo "    -p|--port <port-num>      [Optional] Port number for incoming Trojan-go connection, default 443"
	echo "    -f|--fake <fake-domain>   [Optional] Fake domain name when access Trojan-go without correct password"
	echo "    -k|--hook <hook-url>      [Optional] URL to be hit before server execution, for DDNS update or notification"
	echo "    -c|--china                [Optional] Enable China-site access block to avoid being detected, default disable"
	echo "    --wp <websocket-path>     [Optional] Enable websocket with websocket-path setting, e.g. '/ws'. default disable"
	echo "    --sp <shadowsocks-pass>   [Optional] Enable Shadowsocks AEAD with given password, default disable"
	echo "    --sm <shadowsocks-method> [Optional] Encryption method applied in Shadowsocks AEAD layer, default AES-128-GCM"
	echo "    --share-cert <cert-path>  [Optional] Waiting for cert populating in given path instead of requesting. default disable"
}

TEMP=`getopt -o d:w:p:f:k:c --long domain:,password:,port:,fake:,hook:,china,wp:,sp:,sm:,share-cert: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
	case "$1" in
		-d|--domain)
			DOMAIN="$2"
			shift 2
			;;
		-w|--password)
			PASSWORD="$2"
			shift 2
			;;
		-p|--port)
			PORT="$2"
			shift 2
			;;
		-f|--fake)
			FAKEDOMAIN="$2"
			shift 2
			;;
		-k|--hook)
			HOOKURL="$2"
			shift 2
			;;
		-c|--china)
			BLOCKCHINA="true"
			shift 1
			;;
		--wp)
			if [[ $2 =~ ^\/[A-Za-z0-9_-]{1,16}$ ]]; then
				WSPATH="$2"
				shift 2
			else
				echo "Websocket path must be 1-16 aplhabets, numbers, '-' or '_' started with '/'"
				exit 1
			fi
			;;
		--sp)
			SSPASSWORD="$2"
			shift 2
			;;
		--sm)
			SSMETHOD="$2"
			shift 2
			;;
		--share-cert)
			SHARECERT="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			usage;
			exit 1
			;;
	esac
done

if [ -z "${PASSWORD}" ] || [ -z "${DOMAIN}" ]; then
	usage
	exit 2
fi

if [ -z "${FAKEDOMAIN}" ]; then
	FAKEDOMAIN="www.un.org"
fi

if [ -z "${PORT}" ]; then
	PORT=443
fi

if [ -n "${HOOKURL}" ]; then
	curl -sSL "${HOOKURL}"
	echo
fi

if [ -z "${BLOCKCHINA}" ]; then
	BLOCKCHINA="false"
fi

if [ -z "${SSMETHOD}" ]; then
	SSMETHOD="AES-128-GCM"
fi

if [ -z "${SHARECERT}" ]; then
	CERTPATH="/root/.acme.sh/${NGDOMAIN}"
else
	CERTPATH="${SHARECERT}"
fi

TRY=0
while [ ! -f "${CERTPATH}/fullchain.cer" ]
do
	if [ -n "${SHARECERT}" ]; then
		echo "Cert populating not found, Waitting..."
	else
		echo "Cert requesting..."
		/root/.acme.sh/acme.sh --issue --standalone -d ${DOMAIN}
		((TRY++))
		if [ "${TRY}" -ge 3 ]; then
			echo "Requesting cert for ${NGDOMAIN} failed. Check log please."
			exit 3
		fi
	fi
	echo "Wait 10 seconds before cert checking again..."
	sleep 10
done

cat /etc/trojan-go/server.yaml  \
	| yq -y " .\"local-port\" |= ${PORT} " \
	| yq -y " .\"remote-addr\" |= \"${FAKEDOMAIN}\" " \
	| yq -y " .\"password\"[0] |= \"${PASSWORD}\" " \
	| yq -y " .\"ssl\".\"cert\" |= \"${CERTPATH}/fullchain.cer\" " \
	| yq -y " .\"ssl\".\"key\" |= \"${CERTPATH}/${DOMAIN}.key\" " \
	| yq -y " .\"ssl\".\"sni\" |= \"${DOMAIN}\" " \
	| yq -y " .\"router\".\"enabled\" |= ${BLOCKCHINA} " \
	>/etc/trojan-go/server.yml

if [ -n "${WSPATH}" ]; then
	cat /etc/trojan-go/server.yml \
		|yq -y ". + {websocket:{enabled:true,path:\"${WSPATH}\",host:\"${DOMAIN}\"}}" \
		> /tmp/server.yml.1
	mv /tmp/server.yml.1 /etc/trojan-go/server.yml
fi

if [ -n "${SSPASSWORD}" ]; then
	cat /etc/trojan-go/server.yml \
		|yq -y ". + {shadowsocks:{enabled:true,method:\"${SSMETHOD}\",password:\"${SSPASSWORD}\"}}" \
		> /tmp/server.yml.1
	mv /tmp/server.yml.1 /etc/trojan-go/server.yml
fi

exec /usr/local/bin/trojan-go -config /etc/trojan-go/server.yml
