#!/bin/bash
# collect.sh - collects one sample of Moodle login page response times
# and saves it as raw/YYYY-mm-dd/HHMM.csv (UTC), as described in SOURCE.md.
# On the first run of each day (UTC) it also runs the daily checks
# (ipinfo and traceroute) and saves them under raw/YYYY-mm-dd/daily/.

# Always work from the repository root (the folder above bin/)
cd "$(dirname "$0")/.." || exit 1

# Sample time in UTC, taken once so all lines share the same file
day=$(date -u +%Y-%m-%d)
time=$(date -u +%H%M)

mkdir -p "raw/$day"
file="raw/$day/$time.csv"

# Short site name and URL, one site per line
sites="runi https://moodle.runi.ac.il/2027/login/index.php
tau https://moodle.tau.ac.il/login/index.php
technion https://moodle26.technion.ac.il/login/index.php
ariel https://moodlearn.ariel.ac.il/login/index.php
huji https://moodle.huji.ac.il/2026-27/login/index.php
nottingham https://moodle.nottingham.ac.uk/login/index.php
google https://www.google.com"

fields="%{http_code},%{num_redirects},%{time_total},%{time_connect},%{time_starttransfer},%{remote_ip}"

# ---------- Every run: response time sample ----------

# Header line (> creates the file)
echo "url,mode,http_code,num_redirects,time_total,time_connect,time_starttransfer,remote_ip" > "$file"

echo "$sites" | while read -r name url; do
    # no_follow: only the first response, without following redirects
    curl -s -o /dev/null --max-time 30 \
        -w "$url,no_follow,$fields\n" "$url" >> "$file"

    # follow: follow all redirects (-L) with cookies turned on (-b "")
    curl -s -o /dev/null --max-time 30 -L -b "" \
        -w "$url,follow,$fields\n" "$url" >> "$file"
done

# ---------- Once a day: ipinfo and traceroute ----------

daily="raw/$day/daily"

# If today's daily folder already exists, the daily checks were already done
if [ ! -d "$daily" ]; then
    mkdir -p "$daily"

    echo "$sites" | while read -r name url; do
        # Host name from the URL, for example moodle.tau.ac.il
        host=$(echo "$url" | cut -d/ -f3)

        # Server IP from the no_follow line of the sample we just saved
        ip=$(grep "^$url,no_follow," "$file" | cut -d, -f8)

        # ipinfo: country and owner of the address (the JSON includes the IP)
        if [ -n "$ip" ]; then
            curl -s --max-time 30 "https://ipinfo.io/$ip/json" > "$daily/ipinfo_$name.json"
        fi

        # traceroute: hops to the same IP that curl and ipinfo used
        # (the first line includes the IP). If the site did not answer
        # and there is no IP, use the host name instead.
        if [ -n "$ip" ]; then
            traceroute "$ip" > "$daily/traceroute_$name.txt" 2>&1
        else
            traceroute "$host" > "$daily/traceroute_$name.txt" 2>&1
        fi
    done
fi
