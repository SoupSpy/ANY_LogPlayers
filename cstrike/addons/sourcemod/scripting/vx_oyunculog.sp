#include <sourcemod>
#include <cstrike>
#include <csteamid>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.0.1"
public Plugin myinfo = 
{
	name = "[VX] Oyuncu Log", 
	author = "Yekta.T", 
	description = "Sunucuda bulunmuş tüm oyuncuların loglarını tutar.", 
	version = PLUGIN_VERSION, 
	url = "vortex.oyunboss.net"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// No need for the old GetGameFolderName setup.
	EngineVersion g_engineversion = GetEngineVersion();
	if (g_engineversion != Engine_CSS)
	{
		SetFailState("This plugin was made for use with Counter-Strike: Source only.");
	}
}

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
	
	int iType = 0;
	int iTimeStamp = GetTime();
	
	
	char sName[32], auth[32], sQuery[300], sIP[32]; GetClientName(client, sName, 32);
	GetClientIP(client, sIP, 32); GetClientAuthId(client, AuthId_Steam2, auth, 21);
	Format(sQuery, 300, "SELECT * FROM `VXOyuncuLoglar` WHERE `SteamID`='%s'", auth);
	
	Handle hQuery = INVALID_HANDLE; hQuery = SQL_Query(g_hDB, sQuery);
	if (SQL_FetchRow(hQuery))
	{
		char sNickname[32]; char sdIP[32];
		SQL_FetchString(hQuery, 0, sNickname, 32);
		SQL_FetchString(hQuery, 4, sdIP, 32);
		
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
		
		
		SQL_Query(g_hDB, sQuery);
	} else {
		DataPack data = new DataPack();
		data.WriteCell(client);
		data.WriteCell(iTimeStamp);
		FRAME_RegisterPlayer(data);
	}
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
	
	SQL_Query(g_hDB, sQuery);
	
	CloseHandle(data);
}

public void OnClientDisconnect(int client)
{
	int iTimeStamp = GetTime();
	
	char auth[21], sQuery[300];
	GetClientAuthId(client, AuthId_Steam2, auth, 21);
	
	Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `LastDC`='%i' WHERE `SteamID`='%s'", iTimeStamp, auth);
	SQL_Query(g_hDB, sQuery);
}

public void OnClientSettingsChanged(int client)
{
	if (!g_cPluginStatus)
		return;
	
	RequestFrame(FRAME_SettingsChanged, client);
}

public void FRAME_SettingsChanged(any client)
{
	char sName[32], auth[21], sQuery[300]; GetClientName(client, sName, 32);
	GetClientAuthId(client, AuthId_Steam2, auth, 21);
	Format(sQuery, 300, "SELECT * FROM `VXOyuncuLoglar` WHERE `SteamID`='%s'", auth);
	
	Handle hQuery = INVALID_HANDLE; hQuery = SQL_Query(g_hDB, sQuery);
	if (SQL_FetchRow(hQuery))
	{
		char sNickname[32];
		SQL_FetchString(hQuery, 0, sNickname, 32);
		if (strcmp(sName, sNickname) != 0)
		{
			Format(sQuery, 300, "UPDATE `VXOyuncuLoglar` SET `Nickname`='%s'WHERE `SteamID`='%s'", sName, auth);
		}
		
		
		SQL_Query(g_hDB, sQuery);
	}
}


