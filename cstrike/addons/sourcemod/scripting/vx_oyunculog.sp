#include <sourcemod>
#include <cstrike>
#include <csteamid>

#pragma semicolon 1
#pragma newdecls required

#define MAX_MESSAGE_LENGTH 250

#define PLUGIN_VERSION "0.4"
public Plugin myinfo = 
{
	name = "[VX] Oyuncu Log", 
	author = "Yekta.T", 
	description = "Sunucuda bulunmuş tüm oyuncuların loglarını tutar.", 
	version = PLUGIN_VERSION, 
	url = "vortex.oyunboss.net"
};

ConVar g_chPluginStatus;

Handle g_hDB = INVALID_HANDLE;

char g_sDBError[300];
bool g_cPluginStatus;

public void OnPluginStart()
{
	g_hDB = SQL_Connect("VXOyuncuLog", true, g_sDBError, 300);
	if (g_hDB == INVALID_HANDLE)
		ThrowError("[VX OYUNCU LOG] Veritabanına bağlanamaıyorum. %s", g_sDBError);
	
	SQL_SetCharset(g_hDB, "utf8mb4");
	
	char sQuery[300];
	Format(sQuery, 300, "CREATE TABLE IF NOT EXISTS VXOyuncuLoglar ( Nickname VARCHAR(32) COLLATE utf8mb4_general_ci NOT NULL, SteamID VARCHAR(19) NOT NULL, SteamID3 VARCHAR(19) NOT NULL, SteamID64 VARCHAR(66) NOT NULL, IP VARCHAR(32) NOT NULL, LastConnect INT(255) NULL, LastDC INT(255) NULL, PRIMARY KEY (SteamID64))");
	SQL_FastQuery(g_hDB, sQuery);
	
	HookEvent("player_changename", Event_nameChange, EventHookMode_Post);
	
	g_chPluginStatus = CreateConVar("sm_vxoyunculog_enable", "1", _, _, true, 0.0, true, 1.0);
}

public void OnConfigsExecuted()
{
	g_cPluginStatus = GetConVarBool(g_chPluginStatus);
}

public void OnClientPutInServer(int client)
{
	if (!g_cPluginStatus)
		return;
	
	//CreateTimer(2.0, Timer_PutInServer, client);
	char auth[32], sQuery[300];
	GetClientAuthId(client, AuthId_Steam2, auth, 21);
	Format(sQuery, 300, "SELECT * FROM `VXOyuncuLoglar` WHERE `SteamID`='%s'", auth);
	
	SQL_TQuery(g_hDB, SQL_PutInServer, sQuery, client);
}

public void SQL_PutInServer(Handle owner, Handle hndl, const char[] error, any client)
{
	char sName[32], auth[32], sQuery[300], sIP[32]; GetClientName(client, sName, 32);
	GetClientIP(client, sIP, 32); GetClientAuthId(client, AuthId_Steam2, auth, 21);
	Format(sQuery, 300, "SELECT * FROM `VXOyuncuLoglar` WHERE `SteamID`='%s'", auth);
	
	int iType = 0;
	int iTimeStamp = GetTime();
	
	if (SQL_FetchRow(hndl))
	{
		char sNickname[32]; char sdIP[32];
		SQL_FetchString(hndl, 0, sNickname, 32);
		SQL_FetchString(hndl, 4, sdIP, 32);
		
		if (strcmp(sName, sNickname) != 0)
		{
			iType = 2;
		}
		if (strcmp(sdIP, sIP, false) != 0)
		{
			iType = 6;
		}
		
		
		if (iType == 0)
		{
			Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `LastConnect`='%i' WHERE `SteamID`='%s'", iTimeStamp, auth);
		}
		else
		{
			Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `Nickname`='%s', `IP`='%s',`LastConnect`='%i' WHERE `SteamID`='%s'", sName, sIP, iTimeStamp, auth);
		}
		
		SQL_TQuery(g_hDB, SQL_Connected, sQuery);
		//SQL_FastQuery(g_hDB, sQuery);
	} else {
		DataPack data = new DataPack();
		data.WriteCell(client);
		data.WriteCell(iTimeStamp);
		FRAME_RegisterPlayer(data);
	}
}

public void SQL_Connected(Handle owner, Handle hndl, const char[] error, any client)
{
	
}


public void FRAME_RegisterPlayer(any data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	int iTimeStamp = ReadPackCell(data);
	
	char sName[32], sIP[32], sSteam2[32], sSteam3[32], sSteam64[32], sQuery[300];
	GetClientName(client, sName, 32); GetClientIP(client, sIP, 32); GetClientAuthId(client, AuthId_Steam2, sSteam2, 32);
	GetClientAuthId(client, AuthId_Steam3, sSteam3, 32); GetClientCSteamID(client, sSteam64, 32);
	
	Format(sQuery, 300, "INSERT INTO `VXOyuncuLoglar`(`Nickname`, `SteamID`, `SteamID3`, `SteamID64`, `IP`, `LastConnect`) VALUES ('%s','%s','%s','%s','%s','%d')", 
		sName, sSteam2, sSteam3, sSteam64, sIP, iTimeStamp);
	
	SQL_TQuery(g_hDB, SQL_Register, sQuery);
	//SQL_FastQuery(g_hDB, sQuery);
	
	CloseHandle(data);
}

public void SQL_Register(Handle owner, Handle hndl, const char[] error, any client)

{
	
}


public void OnClientDisconnect(int client)
{
	int iTimeStamp = GetTime();
	
	char auth[21], sQuery[300];
	GetClientAuthId(client, AuthId_Steam2, auth, 21);
	
	Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `LastDC`='%d' WHERE `SteamID`='%s'", iTimeStamp, auth);
	SQL_TQuery(g_hDB, SQL_Left, sQuery);
	//SQL_FastQuery(g_hDB, sQuery);
}

public void SQL_Left(Handle owner, Handle hndl, const char[] error, any client)
{
	
}
public void Event_nameChange(Event event, const char[] name, bool dontBroadcast)
{
	char oldname[32];
	char newname[32];
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetEventString(event, "oldname", oldname, 31);
	GetEventString(event, "newname", newname, 31);
	
	if (!StrEqual(oldname, newname))
	{
		CreateTimer(1.0, FRAME_SettingsChanged, client);
	}
}

public Action FRAME_SettingsChanged(Handle timer, any client)
{
	
	char sName[32], auth[21], sQuery[300]; GetClientName(client, sName, 32);
	GetClientAuthId(client, AuthId_Steam2, auth, 21);
	Format(sQuery, 300, "SELECT * FROM `VXOyuncuLoglar` WHERE `SteamID`='%s'", auth);
	
	SQL_TQuery(g_hDB, SQL_SettingChanged, sQuery, client);
}

public void SQL_SettingChanged(Handle owner, Handle hndl, const char[] error, any client)
{
	if (SQL_FetchRow(hndl))
	{
		char sName[32], auth[21], sQuery[300]; GetClientName(client, sName, 32);
		GetClientAuthId(client, AuthId_Steam2, auth, 21);
		
		char sNickname[32];
		SQL_FetchString(hndl, 0, sNickname, 32);
		if (!StrEqual(sName, sNickname))
		{
			Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `Nickname`='%s'WHERE `SteamID`='%s'", sName, auth);
			DataPack data = new DataPack();
			data.WriteString(sQuery);
			RequestFrame(Frame_NameChanged, data);
			//SQL_FastQuery(g_hDB, sQuery);
		}
		
	}
}

public void Frame_NameChanged(any data)
{
	ResetPack(data);
	char sQuery[300]; ReadPackString(data, sQuery, 300);
	CloseHandle(data);
	SQL_TQuery(g_hDB, SQL_NameChanged, sQuery);
}

public void SQL_NameChanged(Handle owner, Handle hndl, const char[] error, any client)
{
	
}
