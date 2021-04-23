#!/bin/bash

# Simple script to analyze the performance 
# of a Linux server. It relies on several  
# monitoring tools available as part of the sysstat
# package.

# Author: Alexandr Ablovatski
# Email: ablovatskia@denison.edu
# Credits: Netflix Technology Blog (https://netflixtechblog.com/linux-performance-analysis-in-60-000-milliseconds-accc10403c55)
# License: GNU GPL-3

usage="$(basename "$0") [-h] -- script to show server performance

where:
    -h  show this help text"

if [ "$1" == "-h" ]; then
  echo "$usage"
  exit 0
fi


# Check that sysstat package is installed
if ! command -v iostat &> /dev/null
then
    echo "ERROR: iostat could not be found - install sysstat package first!"
    exit
fi

# Show avg number of tasks waiting to run
echo "#############################
uptime
"
uptime
echo
echo "Analyses: Moving sum averages with a 1 minute, 5 minute, and 15 minute
 constant. The three numbers give us some idea of how load is 
 changing over time. If the numbers are large means probably CPU 
 demand, vmstat or mpstat will confirm. These numbers include 
 processes wanting to run on CPU, as well as processes blocked 
 in uninterruptible I/O (usually disk I/O) though.
"

# Show the last 10 system messages, if there are any. 
echo "############################
dmesg | tail
"
dmesg | tail
echo
echo "Analyses: Look for dmesg errors that can cause performance issues.
"

# Show vmstat output
echo "############################
vmstat 1 10
"
vmstat 1 10
echo
echo "Analyses: Column r: Number of processes running on CPU and waiting for a turn.
 It does not include processes blocked in uninterruptible I/O. 
 To interpret: an “r” value greater than the CPU count is saturation.
 free: Free memory in kilobytes. If there are too many digits to count,
 you have enough free memory.
 si, so: Swap-ins and swap-outs. If these are non-zero, you’re out of memory.
 us, sy, id, wa, st: These are breakdowns of CPU time, on average across 
 all CPUs. They are user time, system time (kernel), idle, wait I/O, and 
 stolen time. The CPU time breakdowns will confirm if the CPUs are busy, 
 by adding user + system time. A constant degree of wait I/O points to a 
 disk bottleneck; this is where the CPUs are idle, because tasks are blocked 
 waiting for pending disk I/O.
"

# Show mpstat output
echo "############################
mpstat -P ALL 1 5
"
mpstat -P ALL 1 5
echo
echo "Analyses: This command prints CPU time breakdowns per CPU, which can be used 
 to check for an imbalance. A single hot CPU can be evidence of a 
 single-threaded application.
"


# Show pidstat output
echo "############################
pidstat 1 10
"
pidstat 1 10
echo
echo "Analyses: Pidstat shows per-process summary, identifying processes consuming CPU.
 The %CPU column is the total across all CPUs.
"

# Show iostat output
echo "############################
iostat -xz 1 7
"
iostat -xz 1 7
echo
echo "Analyses of block devices (disks): r/s, w/s, rkB/s, wkB/s: These are the 
 delivered reads, writes, read Kbytes, and write Kbytes per second to the device.
 A performance problem may simply be due to an excessive load applied. 
 await: The average time for the I/O in milliseconds. Larger than expected average 
 times can be an indicator of device saturation, or device problems.
 avgqu-sz: The average number of requests issued to the device. Values greater 
 than 1 can be evidence of saturation.
 %util: Device utilization. This is really a busy percent, showing the time 
 each second that the device was doing work. Values greater than 60% typically 
 lead to poor performance (which should be seen in await). Values close to 100% 
 usually indicate saturation.
"

# Show memory stats
echo "############################
free -m
"
free -m
echo
echo "Analyses: buffers: For the buffer cache, used for block device I/O.
 cached: For the page cache, used by file systems.
 We want to check that these aren’t near-zero in size, which can lead to 
 higher disk I/O (confirm using iostat), and worse performance.
"

# Get top 10 processes consuming system memory
echo "############################
ps -eo pcpu,pmem,pid,ppid,user,stat,args | sort -k 2 -r | head
"
ps -eo pcpu,pmem,pid,ppid,user,stat,args | sort -k 2 -r | head
echo
echo "Analyses: Top 10 processes consuming system memory.
"

# Show major and minor page faults for a PID
echo "############################
Show major and minor page faults for Pid:
echo "ps -o pid,comm,minflt,majflt <ProcessID>"
"

# Get sar output
echo "############################
sar -n DEV 1 10
"
sar -n DEV 1 10
echo
echo "Analyses: Check network interface throughput: rxkB/s and txkB/s, as a measure of 
 workload, and also to check if any limit has been reached.
"

# Show some key TCP metrics
echo "############################
sar -n TCP,ETCP 1 5
"
sar -n TCP,ETCP 1 5
echo
echo "Analyses: List some key TCP metrics. active/s: Number of locally-initiated TCP connections per second.
 passive/s: Number of remotely-initiated TCP connections per second. 
 retrans/s: Number of TCP retransmits per second. Think of active as outbound, and passive as inbound, 
 but this isn’t strictly true (e.g., consider a localhost to localhost connection). Retransmits are a 
 sign of a network or server issue; it may be an unreliable network (e.g., the public Internet), or it 
 may be due a server being overloaded and dropping packets.
"

# See packet drops/loss at hardware level
echo "############################
ip -s link
"
ip -s link
echo
echo "Analyses: See packet drops/errors/collisions at hardware level. 
"

# Analyze issues at network packet level with tcpdump
echo "############################
tcpdump -s 0 -i {INTERFACE} -w {FILEPATH} [filter expression]
"
echo
echo "Analyses: To capture network packet traffic on interface eth0, run #tcpdump -s 0 -i eth0 -w /tmp/tcpdump.pcap
 and hit ctrl+c to terminate the process. Later the same file could be read using the command 
 tcpdump -r /tmp/tcpdump.pcap.
"

# Check configured DNS servers for functinal resolution
echo "############################
ns=$(cat /etc/resolv.conf  | grep -v '^#' | grep nameserver | awk '{print $2}')
for i in $ns; do dig www.google.com @$i| grep time; done
"
ns=$(cat /etc/resolv.conf  | grep -v '^#' | grep nameserver | awk '{print $2}')
for i in $ns; do dig www.google.com @$i| grep time; done
echo
echo "Analyses: Normally, it should be no more than 2-4 msec a query. Slower DNS response may also lead to bad 
 network performance. Check for in-correct DNS configuration.
"

# Show top output
echo "############################
top -n1
"
top -n1
echo
echo "Analyses: see if anything looks wildly different from the earlier commands, which would 
 indicate that load is variable.
"

# Show number of inotify watchers
echo "############################
lsof 2>/dev/null | grep -i inotify | wc -l
"
lsof 2>/dev/null | grep -i inotify | wc -l
echo
echo "Analyses: check number of inotify watchers. Restart the process that owns over 5000.
"

# Show device utilization
echo "############################
df -h | grep dev/sd
"
echo "Filesystem      Size  Used Avail Use% Mounted on" 
df -h | grep dev/sd
echo
echo "Analyses: check for filled-up filesystems.
"
