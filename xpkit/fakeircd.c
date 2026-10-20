/* Minimal IRC server reproducing what crashed Hal Finney's Bitcoin 0.1.0 on
   10/01/2009: hostname notice, 001/004, a WHO reply (352) for a "u" nickname
   (new address), then the same nickname JOINs twice (already-known address ->
   the else branch with mapAddresses.count). Listens on 127.0.0.1:6667.
   Bitcoin 0.1 ends IRC lines with a bare CR. Logs to the console and fakeircd.log.
   Build: gcc -O2 -o fakeircd.exe fakeircd.c -lws2_32 */
#include <winsock2.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

static FILE* flog;
static void logf_(const char* fmt, ...)
{
    va_list ap;
    SYSTEMTIME t; GetLocalTime(&t);
    printf("%02d:%02d:%02d ", t.wHour, t.wMinute, t.wSecond);
    if (flog) fprintf(flog, "%02d:%02d:%02d ", t.wHour, t.wMinute, t.wSecond);
    va_start(ap, fmt); vprintf(fmt, ap); va_end(ap);
    if (flog) { va_start(ap, fmt); vfprintf(flog, fmt, ap); va_end(ap); fflush(flog); }
    fflush(stdout);
}
static void sendline(SOCKET s, const char* line)
{
    char buf[512];
    _snprintf(buf, sizeof(buf), "%s\r\n", line);
    send(s, buf, (int)strlen(buf), 0);
    logf_("IRCD > %s\n", line);
}
int main(void)
{
    const char* nick = "u4HUtbXQT3ySNk";   /* encodes 1.2.3.4:8333, a test address */
    WSADATA wsa; SOCKET ls, c; struct sockaddr_in a; int one = 1;
    flog = fopen("fakeircd.log", "a");
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) { logf_("WSAStartup failed\n"); return 1; }
    ls = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, (const char*)&one, sizeof(one));
    memset(&a, 0, sizeof(a)); a.sin_family = AF_INET; a.sin_port = htons(6667); a.sin_addr.s_addr = inet_addr("127.0.0.1");
    if (bind(ls, (struct sockaddr*)&a, sizeof(a)) != 0 || listen(ls, 5) != 0) { logf_("bind/listen 127.0.0.1:6667 failed (%d)\n", WSAGetLastError()); return 1; }
    logf_("IRCD listening on 127.0.0.1:6667\n");
    for (;;)
    {
        char me[64] = "x", line[1024], buf[512], out[512]; int n = 0, r, i;
        c = accept(ls, NULL, NULL);
        if (c == INVALID_SOCKET) continue;
        logf_("IRCD: client connected\n");
        sendline(c, ":srv NOTICE AUTH :*** Found your hostname");
        while ((r = recv(c, buf, sizeof(buf), 0)) > 0)
        {
            for (i = 0; i < r; i++)
            {
                char ch = buf[i];
                if (ch != '\r' && ch != '\n') { if (n < (int)sizeof(line) - 1) line[n++] = ch; continue; }
                if (n == 0) continue;
                line[n] = 0; n = 0;
                logf_("IRCD < %s\n", line);
                if (strncmp(line, "NICK ", 5) == 0) { strncpy(me, line + 5, sizeof(me) - 1); me[sizeof(me) - 1] = 0; }
                if (strncmp(line, "USER ", 5) == 0)
                {
                    _snprintf(out, sizeof(out), ":srv 001 %s :Welcome", me); sendline(c, out);
                    _snprintf(out, sizeof(out), ":srv 004 %s srv test", me); sendline(c, out);
                }
                if (strncmp(line, "WHO ", 4) == 0)
                {
                    _snprintf(out, sizeof(out), ":srv 352 %s #bitcoin n=u host srv %s H :0 %s", me, nick, nick); sendline(c, out);
                    _snprintf(out, sizeof(out), ":srv 315 %s #bitcoin :End of /WHO list.", me); sendline(c, out);
                    Sleep(3000);
                    logf_("IRCD: JOIN of the already-known %s (0.1.0 should crash here)\n", nick);
                    _snprintf(out, sizeof(out), ":%s!n=u@host JOIN :#bitcoin", nick); sendline(c, out);
                    Sleep(3000);
                    sendline(c, out);
                }
            }
        }
        logf_("IRCD: client gone\n");
        closesocket(c);
    }
    return 0;
}
