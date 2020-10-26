#!/bin/bash

usage() {
	echo "server-trojan-go -d|--domain <domain-name> -w|--password <password> [-p|--port <port-num>] [-f|--fake <fake-domain>] [-k|--hook <hook-url>]"
	echo "    -d|--domain <domain-name> Trojan-go server domain name"
	echo "    -w|--password <password>  Password for Trojan-go service access"
	echo "    -p|--port <port-num>      [Optional] Port number for incoming Trojan-go connection, default 443"
	echo "    -f|--fake <fake-domain>   [Optional] Fake domain name when access Trojan-go without correct password"
	echo "    -k|--hook <hook-url>      [Optional] URL to be hit before server execution, for DDNS update or notification"
	echo "    -c|--china                [Optional] Enable China-site access block to avoid being detected, default disbale"
}

TEMP=`getopt -o d:w:p:f:k:c --long domain:,password:,port:,fake:hook:china -n "$0" -- $@`
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
	FAKEDOMAIN="www.microsoft.com"
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

TRY=0
while [ ! -f "/root/.acme.sh/${DOMAIN}/fullchain.cer" ]
do
	/root/.acme.sh/acme.sh --issue --standalone -d ${DOMAIN}
	((TRY++))
	if [ $TRY >= 3 ]; then
		echo "Obtian cert for ${DOMAIN} failed. Check log please."
		exit 3
	fi
done

cat /etc/trojan-go/server.yaml  \
	| yq -y " .\"local-port\" |= ${PORT} " \
	| yq -y " .\"remote-addr\" |= \"${FAKEDOMAIN}\" " \
	| yq -y " .\"password\"[0] |= \"${PASSWORD}\" " \
	| yq -y " .\"ssl\".\"cert\" |= \"/root/.acme.sh/${DOMAIN}/fullchain.cer\" " \
	| yq -y " .\"ssl\".\"key\" |= \"/root/.acme.sh/${DOMAIN}/${DOMAIN}.key\" " \
	| yq -y " .\"ssl\".\"sni\" |= \"${DOMAIN}\" " \
	| yq -y " .\"router\".\"enabled\" |= ${BLOCKCHINA} " \
	>/etc/trojan-go/server.yml

exec /usr/local/bin/trojan-go -config /etc/trojan-go/server.yml
