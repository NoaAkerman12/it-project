# Data Source Proposals

## Proposal 1: Moodle login page response times at Reichman and Tel Aviv University

Research question: At which hours of the day are the Moodle login page response times the highest at Reichman University and Tel Aviv University, and do both universities experience their slowest response times during the same hours?

Short explanation: As students we often feel that Moodle gets slow at certain times, especially before assignments are due. Every 10 minutes we will send one request to the public login page of Reichman's Moodle and of Tel Aviv University's Moodle (without logging in), and measure how long the Moodle server takes to send its first answer. In our initial samples, both endpoints returned HTTP 303 redirects. We do not follow these redirects, so our measurements reflect the initial response from each Moodle endpoint rather than the redirected login page. We do not measure the full loading of the page or actions after logging in, like submitting an assignment.

Content: For each university in each sample: the time of the measurement (UTC), the name of the university, the HTTP status code and the response times in seconds (connect time, time until the server starts answering, and total time), measured with curl.

URLs:
- Reichman University: https://moodle.runi.ac.il/2027/login/index.php
- Tel Aviv University: https://moodle.tau.ac.il/login/index.php

Update frequency: The response time changes on every request. We plan to sample every 10 minutes.

Expected size: About 200 bytes per sample (100 bytes for each university). With 144 samples a day for about 90 days, this is around 3 MB for the whole semester, so it stays below the 500 MB limit.

Key or password: None. We do not log in and there is no API key.

Data sample (collected on 2026-11-04). For each university, the first number is the HTTP status code (303 is a redirect) and the second number is the total response time in seconds:
- runi (Reichman University): 303 0.280931
- tau (Tel Aviv University): 303 0.362244

## Proposal 2: Status changes of upcoming space launches

Research question: How often does the status of upcoming space launches change before launch day?

Short explanation: Every upcoming space launch has a status that shows how ready it is, for example TBD (the date is not set yet), TBC (there is a date but it is not confirmed) or Go (Go for Launch). The Launch Library 2 API by The Space Devs shows only the current status of each launch, not how it changed in the past. Every 30 minutes we will download the list of upcoming launches, and by comparing the samples we can see when the status of each launch changed and how long before the launch it became Go. We checked and found that the history of planned dates is already saved on another website (Space Right Now), but we did not find a history of launch statuses there, so we focus on the status.

Content: For each launch in each sample: id, name, status, net (the planned date), window_start, window_end and last_updated, from a JSON list of upcoming launches.

URLs:
- Launch Library 2 API, upcoming launches: https://ll.thespacedevs.com/2.3.0/launches/upcoming/?limit=50&mode=list

Update frequency: The records are updated whenever there is new information, several times a day across all launches. We plan to sample every 30 minutes.

Expected size: About 40 KB per sample (50 launches). With 48 samples a day for about 90 days, this is around 170 MB for the whole semester without compression and about 20 to 30 MB with gzip, so it stays below the 500 MB limit.

Key or password: None. Without an account the API allows up to 15 requests per hour, and we need only 2.

Data sample (collected on 2026-11-08). A full sample returns 50 launches and is very long, so we show the name and status of a few of them. The closest launches are mostly Go, and launches that are further away are mostly TBC or TBD (in this sample: 8 Go, 5 TBC and 37 TBD):
- Falcon 9 Block 5 | USSF-627 | Go
- Starship | Starlink Group 31-2 (Starship Flight 15) | TBC
- Soyuz 2.1b | Progress MS-36 (97P) | TBC
- Long March 2F/G | Shenzhou 24 | TBD
- Falcon 9 Block 5 | Cygnus CRS-2 NG-25 | Go
- Falcon 9 Block 5 | NROL-195 | TBD

## Ranking
1. Proposal 1 (Moodle login page response times) is our first choice. It is connected to our everyday life as students, and the data exists only if we measure it.
2. Proposal 2 (status changes of upcoming space launches) is our second choice.
