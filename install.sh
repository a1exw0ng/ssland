#!/bin/sh
# Linux Install script

[[ $EUID -ne 0 ]] && { echo "The root privilege is required. Aborting." >&2;   exit 1; }
type python   >/dev/null 2>&1 || { echo "Python not found. Aborting." >&2;     exit 1; }
type pip      >/dev/null 2>&1 || { echo "Python pip not found. Aborting." >&2; exit 1; }
type ssserver >/dev/null 2>&1 || { pip install shadowsocks; }

pip install -r requirements.txt

if grep -q WIZARD_GENERATED config.py; then

    echo "Found WIZARD_GENERATED mark. Skipping wizard."

else

    default_cfg=/etc/ss.conf
    read -p "Shadowsocks config file [ default: $default_cfg ] = " cfg
    cfg=${cfg:-$default_cfg}

    [[ -f $cfg ]] && echo "WARNING: File exists." || \
        echo "The encrypt method is aes-256-cfb. You can change this later by editing $cfg"

    read -p "User port formular [ default: 6580+id ] = " port
    port=${port:-6580+id}

    sed config.py -r -i                                             \
        -e "s|^USER_SALT.+$|USER_SALT='`openssl rand -base64 16`'|" \
        -e "s|^user_port.+$|user_port=lambda id:${port}|"           \
        -e "s|/etc/ss.conf|${cfg}|"                                 \
        -e "7a# WIZARD_GENERATED = '`date`'"

    echo "Creating the first user, which is also the administrator."
    ./cli.py user add

    git commit -am "Custom configuration snapshot" >/dev/null 2>&1

fi

echo "Update and start Shadowsocks."
./cli.py sys update 2>&1 >/dev/null

function confirm() {
    while true; do
        read -p "$*? (yes/no): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# CRONJOB Install
    CRONFILE=/tmp/ssland.cron.tmp
    EXECCMD="`readlink -f cron.py` -s"
    crontab -l >$CRONFILE
    if confirm Install cronjob and enable traffic statistic
        grep -q "$EXECCMD" $CRONFILE || ({ cat $CRONFILE; echo "59 23 * * * $EXECCMD"; } | crontab -)
    else
        grep -v "$EXECCMD" $CRONFILE | crontab -
    fi
    rm -f $CRONFILE
