#include <sourcemod>
#include <clientprefs>
#include <basecomm>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "PM",
	author = "xSLOW",
	description = "Send a private message to a player",
	version = "1.2.2"
};

bool g_IsPMon[MAXPLAYERS + 1];
char LogsPath[64];

Handle g_PM_Cookie;

ConVar g_cvAdminView;

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("privatemessages.phrases");
    RegConsoleCmd("sm_pm", Command_SendPM);
    RegConsoleCmd("sm_pmon", Command_PMon);
    RegConsoleCmd("sm_pmoff", Command_PMoff);

    BuildPath(Path_SM, LogsPath, sizeof(LogsPath), "logs/pm.txt");

    g_PM_Cookie = RegClientCookie("PM On/Off", "PM On/Off", CookieAccess_Protected);
    
    g_cvAdminView = CreateConVar("sm_pm_admin_view", "0.0", "Can admins see the messages between players?", _, true, 0.0, true, 1.0);
    
    AutoExecConfig(true);
}


public void OnClientPutInServer(int client)
{
	g_IsPMon[client] = true;
	char buffer[64];
	GetClientCookie(client, g_PM_Cookie, buffer, sizeof(buffer));
	if(StrEqual(buffer,"0"))
		g_IsPMon[client] = false;
}


public Action Command_PMoff(int client, int args) 
{
	CPrintToChat(client, " ★ \x02PM\'s are now disabled.");
	g_IsPMon[client] = false;
	SetClientCookie(client, g_PM_Cookie, "0");
}
public Action Command_PMon(int client, int args) 
{
	CPrintToChat(client, " ★ \x04PM\'s are now enabled.");
	g_IsPMon[client] = true;
	SetClientCookie(client, g_PM_Cookie, "1");
}

public Action Command_SendPM(int client, int args)
{
    if(args < 2)
	{
		CReplyToCommand(client, "%t", "Usage");
		return Plugin_Handled;
	}

    char ClientName[32], TargetName[32], iTarget[64], Message[256], TargetSTEAM[32], ClientSTEAM[32], PmLogMessage[256], PmLogTime[512];

    GetCmdArg(1, iTarget, sizeof(iTarget));
    GetCmdArg(2, Message, sizeof(Message));

    int Target = FindTarget(client, iTarget, false, false);

    if(Target == -1)
        return Plugin_Handled;

    if(g_IsPMon[client] == false || g_IsPMon[Target] == false) 
	{
		CPrintToChat(client, "%t", "Target Disabled");
		return Plugin_Handled;
	}

    if(Target == client)
    {
		CReplyToCommand( client, "%t", "Message To Yourself");
		return Plugin_Handled;
    }
    
    if(IsClientValid(Target) && !BaseComm_IsClientGagged(client))
    {
        GetClientName(Target, TargetName, sizeof(TargetName));
        GetClientName(client, ClientName, sizeof(ClientName));
        FormatTime(PmLogTime, sizeof(PmLogTime), "%d/%m/%y - %H:%M:%S", GetTime());
        GetClientAuthId(client, AuthId_Steam2, ClientSTEAM, sizeof(ClientSTEAM));
        GetClientAuthId(Target, AuthId_Steam2, TargetSTEAM, sizeof(TargetSTEAM));

        GetCmdArgString(Message, sizeof(Message));
        ReplaceStringEx(Message, sizeof(Message), iTarget, "", -1, -1, true);

        CPrintToChat(Target, "%t", "PM From", ClientName, Message);
        CPrintToChat(client, "%t", "PM To", TargetName, Message);
        
        if(g_cvAdminView.IntValue == 1)
        {
        	PrintToAdmins(Target, client, Message);	
        }

        Format(PmLogMessage, sizeof(PmLogMessage), "[%s] %s[%s] TO %s[%s]:%s", PmLogTime, ClientName, ClientSTEAM, TargetName, TargetSTEAM, Message);

        Handle FileHandle = OpenFile(LogsPath, "a+");
        WriteFileLine(FileHandle, "%s", PmLogMessage);
        CloseHandle(FileHandle);

        return Plugin_Handled;
    }

    return Plugin_Handled;
}

stock bool IsClientValid(int client)
{
    if (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    return false;
}

void PrintToAdmins(int iTarget, int iClient, const char[] sMessage)
{
	for(int iAdmin = 1; iAdmin <= MaxClients; iAdmin++)
	{
		if(IsClientValid(iAdmin) && GetAdminFlag(GetUserAdmin(iAdmin), Admin_Kick))
		{
			CPrintToChat(iAdmin, "%t", "Admin PM", iClient, iTarget, sMessage);
		}
	}
}
