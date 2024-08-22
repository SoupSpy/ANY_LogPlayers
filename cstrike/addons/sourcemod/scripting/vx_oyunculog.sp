#include <sourcemod>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.7"

enum VXSQL
{
	VXSQL_REGISTER = 0, 
	VXSQL_UPDATE = 1, 
};

bool g_SteamConnection = true;

public Plugin myinfo = 
{
	name = "[VX] Oyuncu Log Sistemi", 
	author = "Yekta.T", 
	description = "Sunucuya giren oyuncuları database loglar.", 
	version = PLUGIN_VERSION, 
	url = "vortexguys.com"
};

Handle g_hDB = INVALID_HANDLE;

public void OnPluginStart()
{
	static char sErr[300];
	g_hDB = SQL_Connect("VXOyuncuLog", true, sErr, 300);
	if (g_hDB == INVALID_HANDLE)
		ThrowError("[VX OYUNCU LOG] Veritabanına bağlanırken hata meydana geldi: %s", sErr);
	
	SQL_SetCharset(g_hDB, "utf8mb4");
	
	char sQuery[300];
	Format(sQuery, 300, "CREATE TABLE IF NOT EXISTS VXOyuncuLoglar ( Nickname VARCHAR(32) COLLATE utf8mb4_general_ci NOT NULL, SteamID VARCHAR(19) NOT NULL, SteamID3 VARCHAR(19) NOT NULL, SteamID64 VARCHAR(32) NOT NULL, IP VARCHAR(32) NOT NULL, LastConnect INT(255) NULL, LastDC INT(255) NULL, PRIMARY KEY (SteamID64))");
	SQL_FastQuery(g_hDB, sQuery);
	
	HookEvent("player_changename", Event_nameChange);
}

public void OnClientPostAdminCheck(int client) {
	if (!g_SteamConnection)return;
	if (IsFakeClient(client)) {
		return;
	}
	
	VX_SqlQuery(client, VXSQL_UPDATE);
}

public void Event_nameChange(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_SteamConnection)return;
	char oldname[32];
	char newname[32];
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetEventString(event, "oldname", oldname, 32);
	GetEventString(event, "newname", newname, 32);
	
	if (StrEqual(oldname, newname, true))return;
	SQL_EscapeString(g_hDB, newname, newname, 32);
	
	char sQuery[300], sID2[32];
	GetClientAuthId(client, AuthId_Steam2, sID2, 32);
	FormatEx(sQuery, 300, "UPDATE `vxoyunculoglar` SET `Nickname`='%s' WHERE SteamID = '%s'", newname, sID2);
	
	SQL_TQuery(g_hDB, VXSQL_NameChanged, sQuery, GetClientUserId(client));
}

public void VXSQL_NameChanged(Handle owner, Handle hndl, const char[] error, any iclient)
{
	int client = GetClientOfUserId(iclient);
	if (!client)return;
	
	if (hndl == INVALID_HANDLE) {
		LogError("[VX-LOG] %N oyuncusunun yeni ismini loglarken hata meydana geldi: %s", client, error);
		return;
	}
}

public void OnClientDisconnect(int client)
{
	if (!g_SteamConnection)return;
	int iTime = GetTime();
	char sQuery[300], sID2[32];
	GetClientAuthId(client, AuthId_Steam2, sID2, 32);
	
	FormatEx(sQuery, 300, "UPDATE `vxoyunculoglar` SET `LastDC`='%d' WHERE `SteamID` = '%s'", iTime, sID2);
	SQL_TQuery(g_hDB, VXSQL_PlayerDisconnected, sQuery, GetClientUserId(client));
}

public void VXSQL_PlayerDisconnected(Handle owner, Handle hndl, const char[] error, any iclient)
{
	int client = GetClientOfUserId(iclient);
	if (!client)return;
	
	if (hndl == INVALID_HANDLE) {
		LogError("[VX-LOG] %N kişisinin sunucudan çıktığı zamanı loglarken sorun oluştu: %s", client, error);
		return;
	}
}

void VX_SqlQuery(int client, any type)
{
	char sName[32], sID2[32], sID3[32], sID64[32], sIP[32], sQuery[300];
	GetClientName(client, sName, 32);
	SQL_EscapeString(g_hDB, sName, sName, 32);
	
	GetClientAuthId(client, AuthId_Steam2, sID2, 32);
	GetClientIP(client, sIP, 32);
	int iConnect = GetTime();
	
	switch (type)
	{
		case VXSQL_UPDATE:
		{
			FormatEx(sQuery, 300, "UPDATE `vxoyunculoglar` SET `Nickname`='%s', `IP`='%s', `LastConnect`='%i' WHERE `SteamID`='%s'", sName, sIP, iConnect, sID2);
			SQL_TQuery(g_hDB, VXSQL_UpdateOnConnect, sQuery, GetClientUserId(client));
		}
		case VXSQL_REGISTER:
		{
			GetClientAuthId(client, AuthId_Steam3, sID3, 32);
			GetClientAuthId(client, AuthId_SteamID64, sID64, 32);
			FormatEx(sQuery, 300, "INSERT INTO `vxoyunculoglar`(`Nickname`, `SteamID`, `SteamID3`, `SteamID64`, `IP`, `LastConnect`) VALUES ('%s','%s','%s','%s','%s','%i')",
			sName, sID2, sID3, sID64, sIP, iConnect);
			
			SQL_TQuery(g_hDB, VXSQL_RegisterOnConnect, sQuery, GetClientUserId(client));
		}
	}
}

public void VXSQL_UpdateOnConnect(Handle owner, Handle hndl, const char[] error, any iclient)
{
	int client = GetClientOfUserId(iclient);
	if (!client)return;
	
	int rows = SQL_GetAffectedRows(g_hDB);
	if (hndl == INVALID_HANDLE) {
		LogError("[VX-LOG] %N oyuncusunun bilgilerini güncellerken hata meydana geldi: %s", client, error);
		return;
	}
	
	if ( !rows )
		VX_SqlQuery(client, VXSQL_REGISTER);
} 

public void VXSQL_RegisterOnConnect(Handle owner, Handle hndl, const char[] error, any iclient)
{
	int client = GetClientOfUserId(iclient);
	if (!client)return;
	
	if (hndl == INVALID_HANDLE) {
		LogError("[VX-LOG] %N oyuncusunun bilgilerini kayıt ederken hata meydana geldi: %s", client, error);
		return;
	}
} 

public void SteamWorks_SteamServersConnected()
{
	if (!g_SteamConnection)
		g_SteamConnection = true;
}

public void SteamWorks_SteamServersConnectFailure()
{
	if (g_SteamConnection)
		g_SteamConnection = false;
}

public void SteamWorks_SteamServersDisconnected()
{
	if (g_SteamConnection)
		g_SteamConnection = false;
} 