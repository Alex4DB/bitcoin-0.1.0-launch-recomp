// Copyright (c) 2009 Satoshi Nakamoto
// Distributed under the MIT/X11 software license, see the accompanying
// file license.txt or http://www.opensource.org/licenses/mit-license.php.

#include "headers.h"




#pragma pack(1)
struct ircaddr
{
    int ip;
    short port;
};

string EncodeAddress(const CAddress& addr)
{
    struct ircaddr tmp;
    tmp.ip    = addr.ip;
    tmp.port  = addr.port;

    vector<unsigned char> vch(UBEGIN(tmp), UEND(tmp));
    return string("u") + EncodeBase58Check(vch);
}

bool DecodeAddress(string str, CAddress& addr)
{
    vector<unsigned char> vch;
    if (!DecodeBase58Check(str.substr(1), vch))
        return false;

    struct ircaddr tmp;
    if (vch.size() != sizeof(tmp))
        return false;
    memcpy(&tmp, &vch[0], sizeof(tmp));

    addr  = CAddress(tmp.ip, tmp.port);
    return true;
}






static bool Send(SOCKET hSocket, const char* pszSend)
{
    if (strstr(pszSend, "PONG") != pszSend)
        printf("SENDING: %s\n", pszSend);
    const char* psz = pszSend;
    const char* pszEnd = psz + strlen(psz);
    while (psz < pszEnd)
    {
        int ret = send(hSocket, psz, pszEnd - psz, 0);
        if (ret < 0)
            return false;
        psz += ret;
    }
    return true;
}

bool RecvLine(SOCKET hSocket, string& strLine)
{
    strLine = "";
    loop
    {
        char c;
        int nBytes = recv(hSocket, &c, 1, 0);
        if (nBytes > 0)
        {
            if (c == '\n')
                continue;
            if (c == '\r')
                return true;
            strLine += c;
        }
        else if (nBytes <= 0)
        {
            if (!strLine.empty())
                return true;
            // socket closed
            printf("IRC socket closed\n");
            return false;
        }
        else
        {
            // socket error
            int nErr = WSAGetLastError();
            if (nErr != WSAEMSGSIZE && nErr != WSAEINTR && nErr != WSAEINPROGRESS)
            {
                printf("IRC recv failed: %d\n", nErr);
                return false;
            }
        }
    }
}

bool RecvLineIRC(SOCKET hSocket, string& strLine)
{
    loop
    {
        bool fRet = RecvLine(hSocket, strLine);
        if (fRet)
        {
            if (fShutdown)
                return false;
            vector<string> vWords;
            ParseString(strLine, ' ', vWords);
            if (vWords[0] == "PING")
            {
                strLine[1] = 'O';
                strLine += '\r';
                Send(hSocket, strLine.c_str());
                continue;
            }
        }
        return fRet;
    }
}

bool RecvUntil(SOCKET hSocket, const char* psz1, const char* psz2=NULL, const char* psz3=NULL)
{
    loop
    {
        string strLine;
        if (!RecvLineIRC(hSocket, strLine))
            return false;
        printf("IRC %s\n", strLine.c_str());
        if (psz1 && strLine.find(psz1) != -1)
            return true;
        if (psz2 && strLine.find(psz2) != -1)
            return true;
        if (psz3 && strLine.find(psz3) != -1)
            return true;
    }
}




// IRCPlaceholderA: PLACEHOLDER, not original code. Stands for unknown launch-day code of the
// same size; never called, so behaviour is unchanged.
void IRCPlaceholderA()
{
    printf("IRCPlaceholderA 0\n");
    printf("IRCPlaceholderA 1\n");
    printf("IRCPlaceholderA 2\n");
    printf("IRCPlaceholderA 3\n");
    printf("IRCPlaceholderA 4\n");
    printf("IRCPlaceholderA 5\n");
    printf("IRCPlaceholderA 6\n");
    printf("IRCPlaceholderA 7\n");
    printf("IRCPlaceholderA 8\n");
    printf("IRCPlaceholderA 9\n");
    printf("IRCPlaceholderA 10\n");
    printf("IRCPlaceholderA 11\n");
    printf("IRCPlaceholderA 12\n");
    printf("IRCPlaceholderA 13\n");
    printf("IRCPlaceholderA 14\n");
    printf("IRCPlaceholderA 15\n");
    printf("IRCPlaceholderA 16\n");
    printf("IRCPlaceholderA 17\n");
    printf("IRCPlaceholderA 18\n");
    printf("IRCPlaceholderA 19\n");
}

bool fRestartIRCSeed = false;

void ThreadIRCSeed(void* parg)
{
    loop
    {
        struct hostent* phostent = gethostbyname("chat.freenode.net");
        CAddress addrConnect(*(u_long*)phostent->h_addr_list[0], htons(6667));

        SOCKET hSocket;
        if (!ConnectSocket(addrConnect, hSocket))
        {
            printf("IRC connect failed\n");
            return;
        }

        if (!RecvUntil(hSocket, "Found your hostname", "using your IP address instead", "Couldn't look up your hostname"))
        {
            closesocket(hSocket);
            return;
        }

        string strMyName = EncodeAddress(addrLocalHost);

        if (!addrLocalHost.IsRoutable())
            strMyName = strprintf("x%u", GetRand(1000000000));

        Send(hSocket, strprintf("NICK %s\r", strMyName.c_str()).c_str());
        Send(hSocket, strprintf("USER %s 8 * : %s\r", strMyName.c_str(), strMyName.c_str()).c_str());

        if (!RecvUntil(hSocket, " 004 "))
        {
            closesocket(hSocket);
            return;
        }
        Sleep(500);

        Send(hSocket, "JOIN #bitcoin\r");
        Send(hSocket, "WHO #bitcoin\r");

        while (!fRestartIRCSeed)
        {
            string strLine;
            if (fShutdown)
            {
                closesocket(hSocket);
                return;
            }
            if (!RecvLineIRC(hSocket, strLine))
            {
                fRestartIRCSeed = true;
                break;
            }
            if (strLine.empty() || strLine[0] != ':')
                continue;
            printf("IRC %s\n", strLine.c_str());

            vector<string> vWords;
            ParseString(strLine, ' ', vWords);
            if (vWords.size() < 2)
                continue;

            char pszName[10000];
            pszName[0] = '\0';

            if (vWords[1] == "352" && vWords.size() >= 8)
            {
                // index 7 is limited to 16 characters
                // could get full length name at index 10, but would be different from join messages
                strcpy(pszName, vWords[7].c_str());
                printf("GOT WHO: [%s]  ", pszName);
            }

            if (vWords[1] == "JOIN")
            {
                // :username!username@50000007.F000000B.90000002.IP JOIN :#channelname
                strcpy(pszName, vWords[0].c_str() + 1);
                if (strchr(pszName, '!'))
                    *strchr(pszName, '!') = '\0';
                printf("GOT JOIN: [%s]  ", pszName);
            }

            if (pszName[0] == 'u')
            {
                CAddress addr;
                if (DecodeAddress(pszName, addr))
                {
                    CAddrDB addrdb;
                    if (AddAddress(addrdb, addr))
                        printf("new  ");
                    else
                    {
                        // make it try connecting sooner
                        CRITICAL_BLOCK(cs_mapAddresses)
                            if (mapAddresses.count(addr.GetKey()))
                                mapAddresses[addr.GetKey()].nLastFailed = 0;
                    }
                    addr.print();
                }
                else
                {
                    printf("decode failed\n");
                }
            }
        }

        fRestartIRCSeed = false;
        closesocket(hSocket);
    }
}










// IRCPlaceholderB: PLACEHOLDER, not original code. Stands for unknown launch-day code of the
// same size; never called, so behaviour is unchanged.
void IRCPlaceholderB()
{
    printf("IRCPlaceholderB 0\n");
    printf("IRCPlaceholderB 1\n");
    printf("IRCPlaceholderB 2\n");
    printf("IRCPlaceholderB 3\n");
    printf("IRCPlaceholderB 4\n");
    printf("IRCPlaceholderB 5\n");
    printf("IRCPlaceholderB 6\n");
    printf("IRCPlaceholderB 7\n");
    printf("IRCPlaceholderB 8\n");
    printf("IRCPlaceholderB 9\n");
    printf("IRCPlaceholderB 10\n");
    printf("IRCPlaceholderB 11\n");
    printf("IRCPlaceholderB 12\n");
    printf("IRCPlaceholderB 13\n");
    printf("IRCPlaceholderB 14\n");
    printf("IRCPlaceholderB 15\n");
    printf("IRCPlaceholderB 16\n");
    printf("IRCPlaceholderB 17\n");
    printf("IRCPlaceholderB 18\n");
    printf("IRCPlaceholderB 19\n");
}

// CIRCPlaceholderInit: PLACEHOLDER, not original code. Size stand-in for unknown
// launch-day code after ThreadIRCSeed; prints nothing (fRestartIRCSeed is false).
struct CIRCPlaceholderInit
{
    CIRCPlaceholderInit()
    {
        if (fRestartIRCSeed)
        {
            printf("CIRCPlaceholderInit 0\n");
            printf("CIRCPlaceholderInit 1\n");
            printf("CIRCPlaceholderInit 2\n");
            printf("CIRCPlaceholderInit 3\n");
            printf("CIRCPlaceholderInit 4\n");
            printf("CIRCPlaceholderInit 5\n");
            printf("CIRCPlaceholderInit 6\n");
            printf("CIRCPlaceholderInit 7\n");
            printf("CIRCPlaceholderInit 8\n");
            printf("CIRCPlaceholderInit 9\n");
            printf("CIRCPlaceholderInit 10\n");
            printf("CIRCPlaceholderInit 11\n");
            printf("CIRCPlaceholderInit 12\n");
            printf("CIRCPlaceholderInit 13\n");
            printf("CIRCPlaceholderInit 14\n");
            printf("CIRCPlaceholderInit 15\n");
            printf("CIRCPlaceholderInit 16\n");
            printf("CIRCPlaceholderInit 17\n");
            printf("CIRCPlaceholderInit 18\n");
            printf("CIRCPlaceholderInit 19\n");
            printf("CIRCPlaceholderInit 20\n");
            printf("CIRCPlaceholderInit 21\n");
            printf("CIRCPlaceholderInit 22\n");
            printf("CIRCPlaceholderInit 23\n");
            printf("CIRCPlaceholderInit 24\n");
            printf("CIRCPlaceholderInit 25\n");
            printf("CIRCPlaceholderInit 26\n");
            printf("CIRCPlaceholderInit 27\n");
            printf("CIRCPlaceholderInit 28\n");
            printf("CIRCPlaceholderInit 29\n");
            printf("CIRCPlaceholderInit 30\n");
            printf("CIRCPlaceholderInit 31\n");
            printf("CIRCPlaceholderInit 32\n");
            printf("CIRCPlaceholderInit 33\n");
            printf("CIRCPlaceholderInit 34\n");
            printf("CIRCPlaceholderInit 35\n");
            printf("CIRCPlaceholderInit 36\n");
            printf("CIRCPlaceholderInit 37\n");
            printf("CIRCPlaceholderInit 38\n");
            printf("CIRCPlaceholderInit 39\n");
            printf("CIRCPlaceholderInit 40\n");
            printf("CIRCPlaceholderInit 41\n");
            printf("CIRCPlaceholderInit 42\n");
            printf("CIRCPlaceholderInit 43\n");
            printf("CIRCPlaceholderInit 44\n");
            printf("CIRCPlaceholderInit 45\n");
            printf("CIRCPlaceholderInit 46\n");
            printf("CIRCPlaceholderInit 47\n");
            printf("CIRCPlaceholderInit 48\n");
            printf("CIRCPlaceholderInit 49\n");
            printf("CIRCPlaceholderInit 50\n");
            printf("CIRCPlaceholderInit 51\n");
            printf("CIRCPlaceholderInit 52\n");
            printf("CIRCPlaceholderInit 53\n");
            printf("CIRCPlaceholderInit 54\n");
            printf("CIRCPlaceholderInit 55\n");
            printf("CIRCPlaceholderInit 56\n");
            printf("CIRCPlaceholderInit 57\n");
            printf("CIRCPlaceholderInit 58\n");
            printf("CIRCPlaceholderInit 59\n");
            printf("CIRCPlaceholderInit 60\n");
            printf("CIRCPlaceholderInit 61\n");
            printf("CIRCPlaceholderInit 62\n");
            printf("CIRCPlaceholderInit 63\n");
            printf("CIRCPlaceholderInit 64\n");
            printf("CIRCPlaceholderInit 65\n");
            printf("CIRCPlaceholderInit 66\n");
            printf("CIRCPlaceholderInit 67\n");
            printf("CIRCPlaceholderInit 68\n");
            printf("CIRCPlaceholderInit 69\n");
        }
    }
} circplaceholderinit;

#ifdef TEST
int main(int argc, char *argv[])
{
    WSADATA wsadata;
    if (WSAStartup(MAKEWORD(2,2), &wsadata) != NO_ERROR)
    {
        printf("Error at WSAStartup()\n");
        return false;
    }

    ThreadIRCSeed(NULL);

    WSACleanup();
    return 0;
}
#endif
