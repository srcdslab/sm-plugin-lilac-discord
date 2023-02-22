#pragma semicolon 1

// Try include since there is no include file for the forwards at the moment
#tryinclude <lilac>

#define PLUGIN_NAME "Lilac_Discord"
#define STEAM_API_CVAR "lilac_steam_api"

#include <RelayHelper>

#pragma newdecls required

Global_Stuffs g_Lilac;

public Plugin myinfo =
{
	name 		= PLUGIN_NAME,
	author 		= ".Rushaway, Dolly, koen",
	version 	= "1.0",
	description = "Send Lilac Detections notifications to discord",
	url 		= "https://nide.gg"
};

public void OnPluginStart() {
	g_Lilac.enable 	= CreateConVar("lilac_discord_enable", "1", "Toggle lilac notification system", _, true, 0.0, true, 1.0);
	g_Lilac.webhook = CreateConVar("lilac_discord", "", "The webhook URL of your Discord channel. (Lilac)", FCVAR_PROTECTED);
	
	RelayHelper_PluginStart();

	AutoExecConfig(true, PLUGIN_NAME);
	
	/* Incase of a late load */
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i) || IsClientSourceTV(i) || g_sClientAvatar[i][0]) {
			return;
		}
		
		OnClientPostAdminCheck(i);
	}
}

public void OnClientPostAdminCheck(int client) {
	if(IsFakeClient(client) || IsClientSourceTV(client)) {
		return;
	}
	
	GetClientSteamAvatar(client);
}

public void OnClientDisconnect(int client) {
	g_sClientAvatar[client][0] = '\0';
}

public void lilac_cheater_detected(int client, int cheat_type, char[] sLine)
{
	/* Plugin Enabled ? */
	if(!g_Lilac.enable.BoolValue) {
		return;
	}

	/* Webhook is set ? */
	char buffer[PLATFORM_MAX_PATH];
	g_Lilac.webhook.GetString(buffer, sizeof(buffer));
	if (buffer[0] == '\0') {
        LogError("[%s] Invalid or no webhook specified for Lilac in cfg/sourcemod/%s.cfg", PLUGIN_NAME);
        return;
    }

	//----------------------------------------------------------------------------------------------------
	/* Generate all content we will need*/
	//----------------------------------------------------------------------------------------------------

	// Name + Formated Text
	char sName[64], sSuspicion[192];
	GetClientName(client, sName, sizeof(sName));
	FormatEx(sSuspicion, sizeof(sSuspicion), "Suspicion of cheating for `%s`", sName);

	// Client details
	char clientAuth[64], cIP[24], cDetails[240];
	GetClientIP(client, cIP, sizeof(cIP));
	if(!GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)))
		strcopy(clientAuth, sizeof(clientAuth), "No SteamID");
		
	FormatEx(cDetails, sizeof(cDetails), "%s \nIP: %s", clientAuth, cIP);

	// Cheat Name
	char sCheat[64];
	GetCheatName(view_as<CHEATS>(cheat_type), sCheat, sizeof(sCheat));

	// Quick Connect
	char ip[20];
	ConVar publicAddr = FindConVar("net_public_adr");
	if(publicAddr != null) {
		publicAddr.GetString(ip, sizeof(ip));
	}
	
	delete publicAddr;
	
	int port = FindConVar("hostport").IntValue;
	
	char connect[128];
	FormatEx(connect, sizeof(connect), "**steam://connect/%s:%i**", ip, port);

	/* Send Embed message */
	SendLilacDiscordMessage(client, sSuspicion, cDetails, sCheat, sLine, connect, buffer);
}
