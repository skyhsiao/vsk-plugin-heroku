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

if [[ -z "${SS_PW}" ]]; then
  SS_PW="herokushadow"
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

V_VER=`wget -qO- "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4`

wget --no-check-certificate -qO '/tmp/v2ray.zip' "https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-$SYS_Bit.zip"
wget --no-check-certificate -qO '/tmp/demo.tar.gz' "https://github.com/Dark11296/vsk-plugin-heroku/raw/master/demo.tar.gz"

unzip /tmp/v2ray.zip -d /tmp
tar xvf /tmp/demo.tar.gz -C /wwwroot

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
        },
        {
            "protocol":"shadowsocks",
            "port":9000,
            "settings":{
                "ota": false,
                "network":"tcp,udp",
                "method":"${Method}",
                "password":"${SS_PW}",
                "level":1
            },
            "streamSettings":{
                "network":"domainsocket"
            }
        },
        {
            "protocol":"dokodemo-door",
            "port":8080,
            "settings":{
                "address":"v1.mux.cool",
                "followRedirect":false,
                "network":"tcp"
            },
            "tag":"ws_in",
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"${SS_Path}"
                }
            }
        }
    ],
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{}
        },
        {
            "protocol":"freedom",
            "tag":"ws_out",
            "streamSettings":{
                "network":"domainsocket"
            }
        }
    ],
    "transport":{
        "dsSettings":{
            "path":"/home/Software/ss-loop.sock"
        }
    },
    "routing":{
        "rules":[
            {
                "type": "field",
                "inboundTag":["ws_in"],
                "outboundTag":"ws_out"
            }
        ]
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

/home/Software/v2ray &
supervisord --nodaemon --configuration /etc/supervisord.conf