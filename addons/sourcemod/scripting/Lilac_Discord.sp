#pragma semicolon 1
#pragma newdecls required

#include <lilac>
#include <discordWebhookAPI>

#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#tryinclude <AutoRecorder>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "Lilac_Discord"
#define WEBHOOK_URL_MAX_SIZE			1000
#define WEBHOOK_THREAD_NAME_MAX_SIZE	100

ConVar g_cvEnable, g_cvWebhook, g_cvWebhookRetry, g_cvAvatar, g_cvUsername, g_cvRedirectURL = null;
ConVar g_cvChannelType, g_cvThreadName, g_cvThreadID;

bool g_Plugin_ExtDiscord = false;
bool g_Plugin_AutoRecorder = false;

char g_sMap[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name 		= PLUGIN_NAME,
	author 		= ".Rushaway, Dolly, koen",
	version 	= "1.1",
	description = "Send Lilac Detections notifications to discord",
	url 		= "https://github.com/srcdslab/sm-plugin-lilac-discord"
};

public void OnPluginStart() {
	/* General config */
	g_cvEnable 	= CreateConVar("lilac_discord_enable", "1", "Toggle lilac notification system", _, true, 0.0, true, 1.0);
	g_cvWebhook = CreateConVar("lilac_discord_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry = CreateConVar("lilac_discord_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvAvatar = CreateConVar("lilac_discord_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
	g_cvUsername = CreateConVar("lilac_discord_username", "Little Anti-Cheat Notification", "Discord username.");
	g_cvRedirectURL = CreateConVar("lilac_discord_redirect", "https://nide.gg/connect/", "URL to your redirect.php file.");
	g_cvChannelType = CreateConVar("lilac_discord_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

	/* Thread config */
	g_cvThreadName = CreateConVar("lilac_discord_threadname", "Lilac - New suspicion", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
	g_cvThreadID = CreateConVar("lilac_discord_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);

	AutoExecConfig(true, PLUGIN_NAME);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
	g_Plugin_AutoRecorder = LibraryExists("AutoRecorder");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = true;
	if (strcmp(sName, "AutoRecorder", false) == 0)
		g_Plugin_AutoRecorder = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = false;
	if (strcmp(sName, "AutoRecorder", false) == 0)
		g_Plugin_AutoRecorder = false;
}

public void OnMapInit(const char[] mapName)
{
	FormatEx(g_sMap, sizeof(g_sMap), mapName);
}

public void lilac_cheater_detected(int client, int cheat_type, char[] sLine)
{
	/* Plugin Enabled ? */
	if(!g_cvEnable.BoolValue) {
		return;
	}

	/* Webhook is set ? */
	char buffer[PLATFORM_MAX_PATH];
	g_cvWebhook.GetString(buffer, sizeof(buffer));
	if (buffer[0] == '\0') {
        LogError("[%s] Invalid or no webhook specified in cfg/sourcemod/%s.cfg", PLUGIN_NAME);
        return;
    }

	#if defined _autorecorder_included
	char sDemo[256];
	if (g_Plugin_AutoRecorder)
	{
		char sDate[32];
		int iCount = -1, iTick = -1, retValTime = -1;
		if (AutoRecorder_IsDemoRecording())
		{
			iCount = AutoRecorder_GetDemoRecordCount();
			iTick = AutoRecorder_GetDemoRecordingTick();
			retValTime = AutoRecorder_GetDemoRecordingTime();
		}
		if (retValTime == -1)
			sDate = "N/A";
		else
			FormatTime(sDate, sizeof(sDate), "%d.%m.%Y @ %H:%M", retValTime);
		FormatEx(sDemo, sizeof(sDemo), "Demo: %d @ Tick: ≈ %d (Started %s)", iCount, iTick, sDate);
	}
	#endif

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
	if(!GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)), false)
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
	
	char connect[128 + 256], sURL[256];
	g_cvRedirectURL.GetString(sURL, sizeof(sURL));
	FormatEx(connect, sizeof(connect), "[%s:%d](%s?ip=%s&port=%d)", ip, port, sURL, ip, port);

	/* Send Embed message */
	SendLilacDiscordMessage(client, sSuspicion, cDetails, sCheat, sLine, sDemo, connect, buffer);
}

stock void SendLilacDiscordMessage(int client, char[] sHeader, char[] sDetails, char[] sCheat, char[] sLine, char[] sDemo, char[] sConnect, char[] sWebhookURL) {
//----------------------------------------------------------------------------------------------------
/* Generate the Webhook */
//----------------------------------------------------------------------------------------------------

	bool IsThread = g_cvChannelType.BoolValue;
	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	Webhook webhook = new Webhook("");

	if (IsThread) {
		if (!sThreadName[0] && !sThreadID[0]) {
			LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
			delete webhook;
			return;
		} else {
			if (strlen(sThreadName) > 0) {
				webhook.SetThreadName(sThreadName);
				sThreadID[0] = '\0';
			}
		}
	}

	/* Webhook UserName */
	char sName[128];
	g_cvUsername.GetString(sName, sizeof(sName));

	/* Webhook Avatar */
	char sAvatar[256];
	g_cvAvatar.GetString(sAvatar, sizeof(sAvatar));

	if (strlen(sName) > 0)
		webhook.SetUsername(sName);
	if (strlen(sAvatar) > 0)
		webhook.SetAvatarURL(sAvatar);

	Embed Embed_1 = new Embed(sHeader, sDetails);
	Embed_1.SetTimeStampNow();
	Embed_1.SetColor(0xf79337);
	
	EmbedField Field_2 = new EmbedField("Reason", sCheat, true);
	Embed_1.AddField(Field_2);

	EmbedField Infos = new EmbedField("Details", sLine, false);
	Embed_1.AddField(Infos);

	EmbedField Map = new EmbedField("Map", g_sMap, false);
	Embed_1.AddField(Map);

#if defined _autorecorder_included
	if (g_Plugin_AutoRecorder)
	{
		EmbedField Demo = new EmbedField("Demo Infos", sDemo, false);
		Embed_1.AddField(Demo);
	}
#endif

	EmbedField Connect = new EmbedField("Quick Connect", sConnect, true);
	Embed_1.AddField(Connect);
	
	EmbedFooter Footer = new EmbedFooter("");
	Footer.SetIconURL("https://github.githubassets.com/images/icons/emoji/unicode/1f440.png");
	Embed_1.SetFooter(Footer);
	delete Footer;

	// Generate the Embed
	webhook.AddEmbed(Embed_1);

	DataPack pack = new DataPack();

	if (IsThread && strlen(sThreadName) <= 0 && strlen(sThreadID) > 0)
		pack.WriteCell(1);
	else
		pack.WriteCell(0);

	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sHeader);
	pack.WriteString(sDetails);
	pack.WriteString(sCheat);
	pack.WriteString(sLine);
	pack.WriteString(sDemo);
	pack.WriteString(sConnect);
	pack.WriteString(sWebhookURL);

	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack, sThreadID);
	delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	char sHeader[192 + MAX_NAME_LENGTH], sDetails[328], sCheat[64], sLine[512], sDemo[256], sConnect[384], sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	static int retries = 0;
	pack.Reset();

	bool IsThreadReply = pack.ReadCell();
	int userid = pack.ReadCell();
	int client = GetClientOfUserId(userid);
	pack.ReadString(sHeader, sizeof(sHeader));
	pack.ReadString(sDetails, sizeof(sDetails));
	pack.ReadString(sCheat, sizeof(sCheat));
	pack.ReadString(sLine, sizeof(sLine));
	pack.ReadString(sDemo, sizeof(sDemo));
	pack.ReadString(sConnect, sizeof(sConnect));
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;
	
	if ((!IsThreadReply && response.Status != HTTPStatus_OK) || (IsThreadReply && response.Status != HTTPStatus_NoContent))
	{
		if (retries < g_cvWebhookRetry.IntValue) {
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			SendLilacDiscordMessage(client, sHeader, sDetails, sCheat, sLine, sDemo, sConnect, sWebhookURL);
			retries++;
			return;
		} else {
			if (!g_Plugin_ExtDiscord)
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#if defined _extendeddiscord_included
			else
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}

	retries = 0;
}
