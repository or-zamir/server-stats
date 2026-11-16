# Server Performance Stats

A Bash script that prints basic performance stats for any Linux server.
Solution to the [roadmap.sh Server Performance Stats](https://roadmap.sh/projects/server-stats) project.

## What it reports

- Total CPU usage (measured over 1 second from `/proc/stat`)
- Memory usage: used vs. free, with percentages
- Disk usage per mount, plus a total, with used and free percentages
- Top 5 processes by CPU
- Top 5 processes by memory
- Stretch goals: OS version, kernel, uptime, load average, logged-in users, failed login attempts

## Usage

```bash
chmod +x server-stats.sh
./server-stats.sh
sudo ./server-stats.sh   # needed to count failed login attempts
```

Requires a Linux system with `/proc`, `ps` (procps) and `df`. It does not run on macOS or Windows; on Windows, use WSL.

Project page URL: https://roadmap.sh/projects/server-stats

On Debian/Ubuntu, install dependencies with `sudo apt install bash coreutils procps gawk`.

CPU usage is sampled over one second. Process CPU percentages are lifetime averages reported by `ps`. Memory used is total minus available memory, so reclaimable caches count as available. Disk statistics cover local mounted filesystems, excluding temporary and squashfs mounts; totals can include multiple views of the same storage. Sizes use GiB.

Disk percentages use filesystem size as their denominator. Free space is space available to ordinary users; filesystem reservations can make used and free percentages add up to less than 100%.

Failed login counts cover retained SSH password-failure records in the system journal, or the current authentication log when the journal is unavailable. They are not an all-time security audit. Elevated permissions may be necessary to see all records.

## Validation

```bash
bash -n server-stats.sh
./server-stats.sh
```
