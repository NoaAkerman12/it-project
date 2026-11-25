# SOURCE.md

## i. Data sources

### Main source: Moodle login pages and control sites

| Name | Address | Data format | Key or username | License | Sampling frequency |
|---|---|---|---|---|---|
| Reichman University Moodle | https://moodle.runi.ac.il/2027/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| Tel Aviv University Moodle | https://moodle.tau.ac.il/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| Technion Moodle | https://moodle26.technion.ac.il/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| Ariel University Moodle | https://moodlearn.ariel.ac.il/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| Hebrew University Moodle | https://moodle.huji.ac.il/2026-27/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| University of Nottingham Moodle (control, abroad) | https://moodle.nottingham.ac.uk/login/index.php | HTTP response, saved as CSV (curl output) | No | No license stated. No robots.txt (404) | Every 10 minutes |
| Google (control, general site) | https://www.google.com | HTTP response, saved as CSV (curl output) | No | robots.txt does not block the home page | Every 10 minutes |

### Supporting sources

| Name | Address | Data format | Key or username | License | Sampling frequency |
|---|---|---|---|---|---|
| ipinfo.io | https://ipinfo.io/IP/json (IP is the server address from the `no_follow` measurement) | JSON | No (free use without a token) | ipinfo.io free use terms | Once a day |
| traceroute | Run from our computer to the server IP from the `no_follow` measurement (to the host name if the site did not answer) | Text | No | Not relevant (a tool we run ourselves) | Once a day |

## ii. Short explanation

Our research question is: At which hours of the day are the Moodle login page response times the highest at five Israeli universities (Reichman, Tel Aviv, Technion, Ariel and Hebrew University), and do all of them experience their slowest response times during the same hours?

We measure how long it takes each Moodle login page to respond. We do not save the page itself, only the measurement. We compare five Israeli universities, and we also measure two control sites. The University of Nottingham is a Moodle site abroad, where students live in a different time zone. Google is a general site that is not related to universities. If all sites get slower at the same hour, the problem is probably our own network. If only the Israeli Moodle sites get slower, it points to load on Moodle.

Not all sites answer in the same way. Reichman, Tel Aviv, Ariel and Hebrew University return an HTTP 303 redirect, while Technion and Nottingham return the login page directly (HTTP 200). This is why we measure every site twice:

1. `no_follow`: only the first response, without following the redirect.
2. `follow`: following all redirects until the real login page (curl `-L`). Here we also turn on cookies (curl `-b ""`). Without cookies, Reichman and Hebrew University ended on an error page instead of the login page.

The `follow` measurement lets us compare Technion and Nottingham fairly with the other sites.

Once a day we also check where each server is. We use ipinfo.io to get the country and the company that owns the address, and traceroute to count the hops (routers) on the way to each server. This helps us explain differences between sites that come from distance and not from load.

All the data is collected by the script `bin/collect.sh`. Each source has its own file, and the file name shows its content. Every run saves the response times of all sites to `raw/YYYY-mm-dd/HHMM_websites.csv` (UTC). The first run of each day (UTC) also runs the daily checks and saves them with the same `HHMM` as that run:

1. `raw/YYYY-mm-dd/HHMM_ipinfo.json`: a JSON array with one object for each of the seven sites, `{"site", "ip", "ipinfo"}`. `site` is the short site name, `ip` is the address that was checked, and `ipinfo` is the answer from ipinfo.io (`null` if there was no address or no valid answer).
2. `raw/YYYY-mm-dd/HHMM_traceroute.txt`: for each site, a `=== site:` line with the short site name, and then the traceroute output. Its first line includes the address that was checked.

Both checks use the server IP from the `no_follow` measurement of that run, so ipinfo and traceroute check the same server that curl measured. traceroute runs with `-n` (addresses only), `-q 1` (one probe per hop) and `-w 2` (wait at most 2 seconds for each hop), so it does not get stuck on servers that do not answer.

Every file is first written to a temporary file in `tmp/`, outside `raw/`, and moved to `raw/` only when it is complete. If a run stops in the middle, nothing is added to `raw/`. The script never replaces a file that is already in `raw/`.

The four manual samples from before the automatic collection (16 to 19 November 2026) are saved as `raw/YYYY-mm-dd/HHMM.csv`, without `_websites`. Files in `raw/` are never renamed, so they keep this name. They have the same columns as the `_websites.csv` files, except `time_connect`, `time_starttransfer` and `remote_ip`.

In our first checks, traceroute showed that Reichman, Technion, Hebrew University and Google are close to us (about 17 ms), and Tel Aviv, Ariel and Nottingham are far (about 75 to 80 ms). At Reichman, Tel Aviv and Ariel, the server that answers us is not Moodle itself but a protection service in front of it. Reichman's address belongs to Google and its host name is under `rbzdns.com`. Tel Aviv's address belongs to F5 Networks and Ariel's to Link11. So the measured time also includes this service. Because of these fixed differences, we compare each university to itself across the hours of the day, and not only the times between universities.

Some addresses depend on the academic year (`/2027/` at Reichman, `moodle26` at Technion, `/2026-27/` at Hebrew University). If a university moves to a new address during the semester, we will update the address and write it in the README.

## iii. Schema

`dataset.csv` has one row for each site, each measurement mode and each sample time.

| Column | Content | Units |
|---|---|---|
| `timestamp_utc` | Date and time of the sample, taken from the file path | ISO 8601, UTC (for example `2026-11-16T10:24Z`) |
| `site` | Short name of the site: `runi`, `tau`, `technion`, `ariel`, `huji`, `nottingham`, `google` | Text |
| `site_group` | `israel` for the five Israeli universities, `abroad` for Nottingham, `general` for Google | Text |
| `mode` | `no_follow` or `follow` | Text |
| `http_code` | HTTP status code. `000` means there was no answer | Code |
| `num_redirects` | Number of redirects until the final page | Count |
| `response_time_ms` | Total time until the full answer arrived | Milliseconds |
| `connect_time_ms` | Time until the connection to the server was open (automatic collection only) | Milliseconds |
| `first_byte_ms` | Time until the first byte of the answer arrived (automatic collection only) | Milliseconds |
| `server_ip` | IP address of the server curl connected to, in every measurement (automatic collection only) | Text |
| `server_country` | Country of the address according to ipinfo | Two letter country code |
| `server_org` | Company that owns the address according to ipinfo | Text |
| `hops` | Number of the last hop that answered in that day's traceroute | Count |
| `reached` | Whether traceroute reached the server itself | `yes` or `no` |

Technion, Hebrew University and Nottingham do not answer traceroute. For them `hops` is the last hop that answered and `reached` is `no`, so their real number of hops is higher.

The response times are measured every 10 minutes, but `server_country`, `server_org`, `hops` and `reached` are checked only once a day. To add the daily data to each row, we match it by IP address. The daily ipinfo and traceroute results include the IP address that was checked. For each site and sample, we compare this address to the `server_ip` of the `no_follow` measurement, which is the first server that answers for that site. If the addresses are the same, the daily data is added to both rows of that sample (`no_follow` and `follow`). If the address is different, for example because the site moved to another server during the day, or if there is no daily data for that day, these four columns stay empty.

## iv. Why we kept these columns

We kept `response_time_ms` because it is the main measurement for our question. `connect_time_ms` and `first_byte_ms` split the total time into parts. A slow connection points to the network, and a slow first byte after a fast connection points to a busy server.

We kept `http_code` and `num_redirects` because they almost never change. When they do change, it means something happened to the site, and we should not use that time as a normal measurement.

We kept `site_group` so we can easily compare the Israeli sites with the control sites.

We kept `server_ip` in every measurement so we can see if the site moves to a different server during the day. If the response time jumps and the address changed too, the jump may come from the new server and not from load.

We kept `server_org`, `server_country`, `hops` and `reached` to explain differences that come from distance. They change very rarely, so we check them only once a day.

We did not keep:

1. The full URL. It is long and repeats in every row, so we replaced it with the short `site` name. The full URL stays in the raw files.
2. The final address after the redirects. It is very long and contains a new one time code every time.
3. The page content. It is not needed for our question, so curl does not save it at all.
4. The city from ipinfo. For Google and F5 addresses it showed cities in the USA, but traceroute showed answer times that are too short for the USA. So the city is not reliable for these servers.
5. The full list of hops from traceroute. We only need how far the server is.

## v. Translation table

| Source | Field in the source | Column in our schema | Change |
|---|---|---|---|
| raw file path | `raw/YYYY-mm-dd/HHMM_websites.csv` (manual samples: `raw/YYYY-mm-dd/HHMM.csv`) | `timestamp_utc` | Built from the folder and file name |
| raw CSV | `url` | `site`, `site_group` | Replaced by a short name and a group |
| raw CSV | `mode` | `mode` | None |
| curl | `%{http_code}` | `http_code` | None |
| curl | `%{num_redirects}` | `num_redirects` | None |
| curl | `%{time_total}` | `response_time_ms` | Seconds × 1000 |
| curl | `%{time_connect}` | `connect_time_ms` | Seconds × 1000 |
| curl | `%{time_starttransfer}` | `first_byte_ms` | Seconds × 1000 |
| curl | `%{remote_ip}` | `server_ip` | None |
| `HHMM_ipinfo.json` | `ip` of each site | None | Used only to match by IP |
| `HHMM_ipinfo.json` | `ipinfo.country` | `server_country` | None |
| `HHMM_ipinfo.json` | `ipinfo.org` | `server_org` | None |
| `HHMM_traceroute.txt` | Address in the first line of each site | None | Used only to match by IP |
| `HHMM_traceroute.txt` | Number of the last line that answered | `hops` | None |
| `HHMM_traceroute.txt` | Is the last line the server address | `reached` | `yes` or `no` |

## vi. Expected size after a semester

We assume about ten weeks (70 days) of automatic collection, every 10 minutes. That is 144 samples a day and about 10,000 samples in total.

`raw/`: one sample file has a header and 14 lines (7 sites × 2 modes), about 1.5 KB. 10,000 × 1.5 KB is about 15 MB. The daily ipinfo and traceroute files (two a day, a few KB each) add less than 1 MB. In total about 16 MB.

`dataset.csv`: 14 rows for each sample, so about 140,000 rows. A row is up to about 140 bytes, so the file will be up to about 20 MB.

Both are far below the 500 MB limit.

## Use of AI

"Hi Chat, we need to prepare a project, and we thought about an idea to check at which hours of the day the Moodle of Reichman and of Tel Aviv University is the slowest, and whether there are hours when both are slow. We want to check if this idea is possible at all, and if the data can be collected automatically during the semester. Help us understand how we can check the response times of the sites from Linux without logging in to Moodle. Explain to us which checks we need to run and what the results we get mean. In the end, help us write everything in English and organize it in a SOURCE.md file in Markdown format, without changing our idea and without adding data that we did not really check."
