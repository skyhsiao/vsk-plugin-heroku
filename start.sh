#! /bin/bash

if [[ -z "${UUID}" ]]; then
  UUID="4890bd47-5180-4b1c-9a5d-3ef686543112"
fi

if [[ -z "${AlterID}" ]]; then
  AlterID="10"
fi

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/FreeApp"
fi

if [[ -z "${SS_Path}" ]]; then
  SS_Path="/black-box"
fi

if [[ -z "${Method}" ]]; then
  Method="aes-256-gcm"
fi

if [[ -z "${SSPW}" ]]; then
  SSPW="herokushadow"
fi

date -R

mkdir /var/tmp/nginx
mkdir /wwwroot

CONF1=$(cat /home/Software/1.conf)
CONF2=$(cat /home/Software/2.conf)
CONF3=$(cat /home/Software/3.conf)
echo -e -n "${CONF1}" > /etc/nginx/conf.d/default.conf
echo -e -n "${SS_Path}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${CONF2}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${V2_Path}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${CONF3}" >> /etc/nginx/conf.d/default.conf

sed -i -E "s/Docker_PORT/${PORT}/" /etc/nginx/conf.d/*.conf
sed -i -E "s/^;listen.owner = .*/listen.owner = $(whoami)/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^user = .*/user = $(whoami)/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^group = (.*)/;group = \1/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^user .*/user $(whoami);/" /etc/nginx/nginx.conf

SYS_Bit="$(getconf LONG_BIT)"

if [ "$VER" = "latest" ]; then
  V_VER=`wget -qO- "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4`
else
  V_VER="v$VER"
fi

wget --no-check-certificate -qO '/tmp/v2ray.zip' "https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-$SYS_Bit.zip"
wget --no-check-certificate -qO '/tmp/demo.tar.gz' "https://github.com/Dark11296/vsk-plugin-heroku/raw/master/demo.tar.gz"
wget --no-check-certificate -qO '/tmp/v2ray-plugin.tar.gz' "https://github.com/Dark11296/vsk-plugin-heroku/raw/master/v2ray-plugin-linux-$SYS_Bit.tar.gz"

unzip /tmp/v2ray.zip -d /tmp
tar xvf /tmp/demo.tar.gz -C /wwwroot
tar xvf /tmp/v2ray-plugin.tar.gz -C /home/Software

if [ ! -d /tmp/v2ray-$V_VER-linux-$SYS_Bit ]; then
  CorePath="/tmp"
else
  CorePath="/tmp/v2ray-$V_VER-linux-$SYS_Bit"
fi

cp "${CorePath}/v2ray" "/home/Software/v2ray"
cp "${CorePath}/v2ctl" "/home/Software/v2ctl"
cp "${CorePath}/geoip.dat" "/home/Software/geoip.dat"
cp "${CorePath}/geosite.dat" "/home/Software/geosite.dat"
chmod +x /home/Software/*

function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -r | head -n 1)" != "$1"; }

if version_lt $V_VER "v4.0"; then
cat <<-EOF > /home/Software/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbound":{
        "protocol":"vmess",
        "port":2333,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
            "network":"ws",
            "wsSettings":{
                "path":"${V2_Path}"
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{}
    },
    "policy":{
        "levels":{
            "1":{
                "handshake":10,
                "connIdle":300,
                "uplinkOnly":0,
                "downlinkOnly":0,
                "bufferSize":0
            }
        }
    }
}
EOF
else
cat <<-EOF > /home/Software/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbounds":[
        {
            "protocol":"vmess",
            "port":2333,
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":1,
                        "alterId":${AlterID}
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"${V2_Path}"
                }
            }
        }
    ],
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
            }
        }
    ],
    "policy":{
        "levels":{
            "1":{
                "handshake":10,
                "connIdle":300,
                "uplinkOnly":0,
                "downlinkOnly":0,
                "bufferSize":0
            }
        }
    }
}
EOF
fi

cat <<-EOF > /home/Software/ss.json
{
    "server":"0.0.0.0",
    "server_port":8080,
    "local_port":1080,
    "password":"${SSPW}",
    "timeout":120,
    "method":"${Method}",
    "plugin":"/home/Software/v2ray-plugin_linux_amd64",
    "plugin_opts":"server;mode=websocket;path=${SS_Path};loglevel=none"
}
EOF

ss-server -c /home/Software/ss.json &
/home/Software/v2ray &
supervisord --nodaemon --configuration /etc/supervisord.conf