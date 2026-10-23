#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <math.h>

#define DEFAULT_IFACE "wlp0s20f3"
#define DEFAULT_BAT "BAT0"
#define DEFAULT_SAMPLE_MS 250
#define DEFAULT_TIMEOUT_MS 15000
#define NOTIFY_REPLACE_ID 4242

static int read_file_buf(const char *path, char *buf, size_t max_len) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    ssize_t n = read(fd, buf, max_len - 1);
    close(fd);
    if (n < 0) return -1;
    buf[n] = '\0';
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r' || buf[n - 1] == ' ')) {
        buf[--n] = '\0';
    }
    return 0;
}

static int read_file_ull(const char *path, unsigned long long *val) {
    char buf[64];
    if (read_file_buf(path, buf, sizeof(buf)) != 0) return -1;
    char *endptr = NULL;
    *val = strtoull(buf, &endptr, 10);
    return (endptr != buf) ? 0 : -1;
}

static void get_mem_usage(char *out, size_t out_sz) {
    char buf[2048];
    if (read_file_buf("/proc/meminfo", buf, sizeof(buf)) != 0) {
        snprintf(out, out_sz, "unknown");
        return;
    }

    unsigned long long total = 0, free = 0, buffers = 0, cached = 0, sreclaimable = 0, shmem = 0;
    char *p;
    if ((p = strstr(buf, "MemTotal:")))     sscanf(p, "MemTotal: %llu kB", &total);
    if ((p = strstr(buf, "MemFree:")))      sscanf(p, "MemFree: %llu kB", &free);
    if ((p = strstr(buf, "Buffers:")))      sscanf(p, "Buffers: %llu kB", &buffers);
    if ((p = strstr(buf, "Cached:")))       sscanf(p, "Cached: %llu kB", &cached);
    if ((p = strstr(buf, "SReclaimable:"))) sscanf(p, "SReclaimable: %llu kB", &sreclaimable);
    if ((p = strstr(buf, "Shmem:")))        sscanf(p, "Shmem: %llu kB", &shmem);

    if (total == 0) {
        snprintf(out, out_sz, "unknown");
        return;
    }

    unsigned long long non_used = free + buffers + cached + sreclaimable;
    unsigned long long used = 0;
    if (total + shmem > non_used) {
        used = (total + shmem) - non_used;
    }

    if (used >= 1048576) {
        snprintf(out, out_sz, "%.1f GiB", (double)used / 1048576.0);
    } else {
        snprintf(out, out_sz, "%.0f MiB", (double)used / 1024.0);
    }
}

static void format_duration(double hours, char *out, size_t out_sz) {
    if (hours <= 0.0) {
        snprintf(out, out_sz, "unknown");
        return;
    }
    int total_minutes = (int)(hours * 60.0 + 0.5);
    snprintf(out, out_sz, "%dh %02dm", total_minutes / 60, total_minutes % 60);
}

static void get_battery_display(const char *bat_name, char *out, size_t out_sz) {
    char base[256];
    snprintf(base, sizeof(base), "/sys/class/power_supply/%s", bat_name);

    char path[512];
    snprintf(path, sizeof(path), "%s/capacity", base);
    unsigned long long capacity = 0;
    if (read_file_ull(path, &capacity) != 0) {
        snprintf(out, out_sz, "N/A");
        return;
    }

    char status[64] = {0};
    snprintf(path, sizeof(path), "%s/status", base);
    read_file_buf(path, status, sizeof(status));

    char time_str[64] = "unknown";
    unsigned long long energy_now = 0, power_now = 0;
    unsigned long long charge_now = 0, current_now = 0;

    snprintf(path, sizeof(path), "%s/energy_now", base);
    int has_energy = (read_file_ull(path, &energy_now) == 0);
    snprintf(path, sizeof(path), "%s/power_now", base);
    int has_power = (read_file_ull(path, &power_now) == 0);

    if (has_energy && has_power && power_now > 0) {
        format_duration((double)energy_now / (double)power_now, time_str, sizeof(time_str));
    } else {
        snprintf(path, sizeof(path), "%s/charge_now", base);
        int has_charge = (read_file_ull(path, &charge_now) == 0);
        snprintf(path, sizeof(path), "%s/current_now", base);
        int has_current = (read_file_ull(path, &current_now) == 0);

        if (has_charge && has_current && current_now > 0) {
            format_duration((double)charge_now / (double)current_now, time_str, sizeof(time_str));
        }
    }

    if (strcmp(time_str, "unknown") != 0) {
        snprintf(out, out_sz, "%llu%% (%s)", capacity, time_str);
    } else if (status[0] != '\0' && strcmp(status, "unknown") != 0) {
        snprintf(out, out_sz, "%llu%% (%s)", capacity, status);
    } else {
        snprintf(out, out_sz, "%llu%%", capacity);
    }
}

static void get_temperature(char *out, size_t out_sz) {
    glob_t globbuf;
    if (glob("/sys/class/hwmon/hwmon*/temp*_input", 0, NULL, &globbuf) != 0) {
        snprintf(out, out_sz, "unknown");
        return;
    }

    char fallback_path[512] = {0};
    int found = 0;

    for (size_t i = 0; i < globbuf.gl_pathc; i++) {
        const char *input_path = globbuf.gl_pathv[i];
        if (access(input_path, R_OK) != 0) continue;

        if (fallback_path[0] == '\0') {
            strncpy(fallback_path, input_path, sizeof(fallback_path) - 1);
        }

        // Derive label path: replace "_input" with "_label"
        char label_path[512];
        strncpy(label_path, input_path, sizeof(label_path) - 1);
        label_path[sizeof(label_path) - 1] = '\0';
        char *sub = strstr(label_path, "_input");
        if (sub) {
            strcpy(sub, "_label");
            char label[128] = {0};
            if (read_file_buf(label_path, label, sizeof(label)) == 0) {
                if (strstr(label, "Package") || strstr(label, "Tctl") ||
                    strstr(label, "Tdie") || strstr(label, "CPU") ||
                    strstr(label, "Core")) {
                    unsigned long long mdeg = 0;
                    if (read_file_ull(input_path, &mdeg) == 0) {
                        snprintf(out, out_sz, "%.0f°C", (double)mdeg / 1000.0);
                        found = 1;
                        break;
                    }
                }
            }
        }
    }

    if (!found && fallback_path[0] != '\0') {
        unsigned long long mdeg = 0;
        if (read_file_ull(fallback_path, &mdeg) == 0) {
            snprintf(out, out_sz, "%.0f°C", (double)mdeg / 1000.0);
            found = 1;
        }
    }

    if (!found) {
        snprintf(out, out_sz, "unknown");
    }

    globfree(&globbuf);
}

static int read_cpu_counters(unsigned long long *total, unsigned long long *idle_sum) {
    char buf[512];
    if (read_file_buf("/proc/stat", buf, sizeof(buf)) != 0) return -1;

    unsigned long long user = 0, nice = 0, sys = 0, idle = 0, iowait = 0, irq = 0, softirq = 0, steal = 0;
    if (sscanf(buf, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
               &user, &nice, &sys, &idle, &iowait, &irq, &softirq, &steal) < 4) {
        return -1;
    }
    *total = user + nice + sys + idle + iowait + irq + softirq + steal;
    *idle_sum = idle + iowait;
    return 0;
}

static void read_net_bytes(const char *iface, unsigned long long *rx, unsigned long long *tx) {
    char path[512];
    snprintf(path, sizeof(path), "/sys/class/net/%s/statistics/rx_bytes", iface);
    if (read_file_ull(path, rx) != 0) *rx = 0;
    snprintf(path, sizeof(path), "/sys/class/net/%s/statistics/tx_bytes", iface);
    if (read_file_ull(path, tx) != 0) *tx = 0;
}

static void format_rate(double bytes, double seconds, char *out, size_t out_sz) {
    double rate = bytes / seconds;
    if (rate >= 1048576.0) {
        snprintf(out, out_sz, "%.1f MiB/s", rate / 1048576.0);
    } else if (rate >= 1024.0) {
        snprintf(out, out_sz, "%.0f KiB/s", rate / 1024.0);
    } else {
        snprintf(out, out_sz, "%.0f B/s", rate);
    }
}

static void build_notification_message(char *buf, size_t buf_sz,
                                       const char *download,
                                       const char *upload,
                                       const char *battery,
                                       const char *memory,
                                       const char *cpu,
                                       const char *temp) {
    snprintf(buf, buf_sz,
"<span font_family=\"monospace\">\n"
"<b>Resource</b>     │ <b>Status</b>\n"
"─────────────┼────────────────\n"
" Download   │ %s\n"
" Upload     │ %s\n"
"󰫆 Battery    │ %s\n"
"󰓅 Memory     │ %s\n"
"󰈸 CPU        │ %s\n"
" Temp       │ %s\n"
"</span>",
        download, upload, battery, memory, cpu, temp);
}

static void send_notification(const char *msg, const char *icon_path, int timeout_ms, int replace_id) {
    pid_t pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        char t_str[32], r_str[32];
        snprintf(t_str, sizeof(t_str), "%d", timeout_ms);
        snprintf(r_str, sizeof(r_str), "%d", replace_id);

        if (access("/bin/dunstify", X_OK) == 0 || access("/usr/bin/dunstify", X_OK) == 0) {
            char *args[] = {
                "dunstify",
                "-h", "int:suppress-sound:1",
                "-I", (char *)icon_path,
                "-u", "low",
                "-t", t_str,
                "-r", r_str,
                "System monitor",
                (char *)msg,
                NULL
            };
            execvp("dunstify", args);
            _exit(1);
        }

        char *args[] = {
            "notify-send",
            "-a", "System monitor",
            "-h", "int:suppress-sound:1",
            "-u", "low",
            "-t", t_str,
            "System monitor",
            (char *)msg,
            NULL
        };
        execvp("notify-send", args);
        _exit(1);
    }
    int status;
    waitpid(pid, &status, 0);
}

int main(int argc, char *argv[]) {
    const char *iface = DEFAULT_IFACE;
    const char *battery_dev = DEFAULT_BAT;
    int sample_ms = DEFAULT_SAMPLE_MS;
    int timeout_ms = DEFAULT_TIMEOUT_MS;
    int stdout_only = 0;

    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--stdout") == 0)) {
            stdout_only = 1;
        } else if ((strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--interface") == 0) && i + 1 < argc) {
            iface = argv[++i];
        } else if ((strcmp(argv[i], "-b") == 0 || strcmp(argv[i], "--battery") == 0) && i + 1 < argc) {
            battery_dev = argv[++i];
        } else if ((strcmp(argv[i], "-t") == 0 || strcmp(argv[i], "--interval") == 0) && i + 1 < argc) {
            sample_ms = atoi(argv[++i]);
            if (sample_ms <= 0) sample_ms = DEFAULT_SAMPLE_MS;
        } else if ((strcmp(argv[i], "-T") == 0 || strcmp(argv[i], "--timeout") == 0) && i + 1 < argc) {
            timeout_ms = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            printf("Usage: %s [OPTIONS]\n"
                   "Options:\n"
                   "  -s, --stdout        Print output to stdout instead of desktop notification\n"
                   "  -i, --interface IF  Network interface to monitor (default: %s)\n"
                   "  -b, --battery DEV   Battery device to monitor (default: %s)\n"
                   "  -t, --interval MS   Sampling interval in ms (default: %d)\n"
                   "  -T, --timeout MS    Notification timeout in ms (default: %d)\n"
                   "  -h, --help          Show this help message\n",
                   argv[0], DEFAULT_IFACE, DEFAULT_BAT, DEFAULT_SAMPLE_MS, DEFAULT_TIMEOUT_MS);
            return 0;
        }
    }

    // Auto-detect iface if specified one doesn't exist
    char iface_path[256];
    snprintf(iface_path, sizeof(iface_path), "/sys/class/net/%s", iface);
    if (access(iface_path, F_OK) != 0) {
        glob_t g;
        if (glob("/sys/class/net/*", 0, NULL, &g) == 0) {
            for (size_t i = 0; i < g.gl_pathc; i++) {
                char *name = strrchr(g.gl_pathv[i], '/');
                if (name && strcmp(name + 1, "lo") != 0) {
                    iface = name + 1;
                    break;
                }
            }
            globfree(&g);
        }
    }

    // Resolve icon path
    // char icon_path[512] = "~/.config/dunst/Icons/system-monitor.png";
    char icon_path[512] = "~/.config/dunst/Icons/system-monitor-AI.png";
    const char *home = getenv("HOME");
    if (home) {
        snprintf(icon_path, sizeof(icon_path), "%s/.config/dunst/Icons/system-monitor-AI.png", home);
        if (access(icon_path, R_OK) != 0) {
            snprintf(icon_path, sizeof(icon_path), "%s/.local/share/icons/Notification/system-monitor-AI.png", home);
        }
    }

    // 1. Gather static metrics
    char memory_usage[64];
    get_mem_usage(memory_usage, sizeof(memory_usage));

    char battery_display[128];
    get_battery_display(battery_dev, battery_display, sizeof(battery_display));

    char temperature[64];
    get_temperature(temperature, sizeof(temperature));

    // 2. Initial counters
    unsigned long long cpu_total1 = 0, cpu_idle1 = 0;
    read_cpu_counters(&cpu_total1, &cpu_idle1);

    unsigned long long rx1 = 0, tx1 = 0;
    read_net_bytes(iface, &rx1, &tx1);

    char msg[1024];
    if (!stdout_only) {
        // Instant notification with placeholders
        build_notification_message(msg, sizeof(msg),
                                   "...", "...",
                                   battery_display,
                                   memory_usage,
                                   "...",
                                   temperature);
        send_notification(msg, icon_path, timeout_ms, NOTIFY_REPLACE_ID);
    }

    // 3. Sleep sample interval
    struct timespec req;
    req.tv_sec = sample_ms / 1000;
    req.tv_nsec = (long)(sample_ms % 1000) * 1000000L;
    nanosleep(&req, NULL);

    // 4. Final counters
    unsigned long long cpu_total2 = 0, cpu_idle2 = 0;
    read_cpu_counters(&cpu_total2, &cpu_idle2);

    unsigned long long rx2 = 0, tx2 = 0;
    read_net_bytes(iface, &rx2, &tx2);

    // CPU Usage calculation
    char cpu_usage[64] = "unknown";
    if (cpu_total2 > cpu_total1) {
        unsigned long long total_delta = cpu_total2 - cpu_total1;
        unsigned long long idle_delta = (cpu_idle2 >= cpu_idle1) ? (cpu_idle2 - cpu_idle1) : 0;
        double usage = (1.0 - (double)idle_delta / (double)total_delta) * 100.0;
        if (usage < 0.0) usage = 0.0;
        if (usage > 100.0) usage = 100.0;
        snprintf(cpu_usage, sizeof(cpu_usage), "%.0f%%", usage);
    }

    // Network Rates calculation
    double interval_sec = (double)sample_ms / 1000.0;
    double rx_delta = (rx2 >= rx1) ? (double)(rx2 - rx1) : 0.0;
    double tx_delta = (tx2 >= tx1) ? (double)(tx2 - tx1) : 0.0;

    char download_rate[64], upload_rate[64];
    format_rate(rx_delta, interval_sec, download_rate, sizeof(download_rate));
    format_rate(tx_delta, interval_sec, upload_rate, sizeof(upload_rate));

    // 5. Build and send updated message
    build_notification_message(msg, sizeof(msg),
                               download_rate,
                               upload_rate,
                               battery_display,
                               memory_usage,
                               cpu_usage,
                               temperature);

    if (stdout_only) {
        printf("%s\n", msg);
    } else {
        send_notification(msg, icon_path, timeout_ms, NOTIFY_REPLACE_ID);
    }

    return 0;
}
