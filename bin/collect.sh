#!/bin/bash
# collect.sh - collects one sample of Moodle login page response times
# and saves it as raw/YYYY-mm-dd/HHMM_websites.csv (UTC), as described
# in SOURCE.md.
# On the first run of each day (UTC) it also runs the daily checks and
# saves them as raw/YYYY-mm-dd/HHMM_ipinfo.json and
# raw/YYYY-mm-dd/HHMM_traceroute.txt.
# Files are first written to tmp/ and moved to raw/ only when complete.

# Always work from the repository root (the folder above bin/)
cd "$(dirname "$0")/.." || exit 1

# Sample time in UTC, taken once so all files of this run share it
day=$(date -u +%Y-%m-%d)
time=$(date -u +%H%M)

mkdir -p "raw/$day" tmp || exit 1
websites_file="raw/$day/${time}_websites.csv"
ipinfo_file="raw/$day/${time}_ipinfo.json"
traceroute_file="raw/$day/${time}_traceroute.txt"

# Temporary files outside raw/. They are deleted when the script ends,
# so an unfinished file never stays behind.
tmp_websites=$(mktemp tmp/websites.XXXXXX) || exit 1
tmp_ipinfo=$(mktemp tmp/ipinfo.XXXXXX) || exit 1
tmp_traceroute=$(mktemp tmp/traceroute.XXXXXX) || exit 1
tmp_answer=$(mktemp tmp/answer.XXXXXX) || exit 1
trap 'rm -f "$tmp_websites" "$tmp_ipinfo" "$tmp_traceroute" "$tmp_answer"' EXIT

status=0

# Move a complete file from tmp/ to raw/. Never replace a file that is
# already in raw/ (for example, two runs in the same minute): raw/ is
# append-only.
save() {
    if [ -e "$2" ]; then
        status=1
    else
        mv "$1" "$2" || status=1
    fi
}

# Short site name and URL, one site per line
sites="runi https://moodle.runi.ac.il/2027/login/index.php
tau https://moodle.tau.ac.il/login/index.php
technion https://moodle26.technion.ac.il/login/index.php
ariel https://moodlearn.ariel.ac.il/login/index.php
huji https://moodle.huji.ac.il/2026-27/login/index.php
nottingham https://moodle.nottingham.ac.uk/login/index.php
google https://www.google.com"

fields="%{http_code},%{num_redirects},%{time_total},%{time_connect},%{time_starttransfer},%{remote_ip}"

# ---------- Every run: response times of the websites ----------

# Header line (> creates the file)
echo "url,mode,http_code,num_redirects,time_total,time_connect,time_starttransfer,remote_ip" > "$tmp_websites"

echo "$sites" | while read -r name url; do
    # no_follow: only the first response, without following redirects
    curl -s -o /dev/null --max-time 30 \
        -w "$url,no_follow,$fields\n" "$url" >> "$tmp_websites"

    # follow: follow all redirects (-L) with cookies turned on (-b "")
    curl -s -o /dev/null --max-time 30 -L -b "" \
        -w "$url,follow,$fields\n" "$url" >> "$tmp_websites"
done

# The sample is complete: move it to raw/
save "$tmp_websites" "$websites_file"

# ---------- Once a day: ipinfo and traceroute ----------

# If raw/ already has daily files for today, the daily checks were already done
if ! ls "raw/$day/"*_ipinfo.json "raw/$day/"*_traceroute.txt > /dev/null 2>&1 \
   && [ -f "$websites_file" ]; then

    echo "$sites" | while read -r name url; do
        # Host name from the URL, for example moodle.tau.ac.il
        host=$(echo "$url" | cut -d/ -f3)

        # Server IP from the no_follow line of the sample we just saved
        ip=$(grep "^$url,no_follow," "$websites_file" | cut -d, -f8)

        # ipinfo: country and owner of the address.
        # One JSON object per site: {"site", "ip", "ipinfo"}.
        # "ipinfo" is null if there was no IP or no valid answer.
        : > "$tmp_answer"
        if [ -n "$ip" ]; then
            curl -s --max-time 30 "https://ipinfo.io/$ip/json" > "$tmp_answer"
        fi
        answer=$(jq -c . "$tmp_answer" 2> /dev/null)
        [ -z "$answer" ] && answer=null
        jq -n -c --arg site "$name" --arg ip "$ip" --argjson ipinfo "$answer" \
            '{site: $site, ip: $ip, ipinfo: $ipinfo}' >> "$tmp_ipinfo"

        # traceroute to the same IP that curl and ipinfo used
        # (the host name if the site did not answer).
        # -n: show addresses only, -q 1: one probe per hop,
        # -w 2: wait at most 2 seconds for each hop, so it cannot get stuck.
        echo "=== site: $name" >> "$tmp_traceroute"
        if [ -n "$ip" ]; then
            traceroute -n -q 1 -w 2 "$ip" >> "$tmp_traceroute" 2>&1
        else
            traceroute -n -q 1 -w 2 "$host" >> "$tmp_traceroute" 2>&1
        fi
    done

    # The daily files are complete: move them to raw/.
    # The seven ipinfo objects are first put in one JSON array, so the
    # file is valid JSON. If that fails, the ipinfo file is not saved.
    if jq -s . "$tmp_ipinfo" > "$tmp_answer"; then
        save "$tmp_answer" "$ipinfo_file"
    else
        status=1
    fi
    save "$tmp_traceroute" "$traceroute_file"
fi

# 0 = success, 1 = a file could not be saved to raw/
exit $status
