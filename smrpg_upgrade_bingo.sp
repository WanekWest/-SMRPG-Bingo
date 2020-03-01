#pragma newdecls required
#pragma semicolon 1
#include <smrpg>
#include <sdkhooks>

#define UPGRADE_SHORTNAME "bingo"
#define UPGRADE_SHORTNAME_anti "antibingo"
#define PLUGIN_VERSION "1.1"

float g_hBingoChance,g_DebugMode;

enum WeaponConfig {
	Float:Weapon_Chance,
};

StringMap g_hWeaponDamage;

public Plugin myinfo = 
{
	name = "SM:RPG Upgrade > Bingo",
	author = "WanekWest",
	description = "Give a small chance for kill player.",
	version = PLUGIN_VERSION,
	url = "https://vk.com/wanek_west"
}

public void OnPluginStart()
{
	HookEvent("player_hurt", EventPlayerHurt);
	LoadTranslations("smrpg_stock_upgrades.phrases");

	g_hWeaponDamage = new StringMap();
}

public void OnMapStart()
{
	if(!LoadWeaponConfig())
	{
		SetFailState("Can't read config file in configs/smrpg/bingo_weapons.cfg!");
	}
}


void EventPlayerHurt(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid")),attacker = GetClientOfUserId(hEvent.GetInt("attacker")),iLevel = SMRPG_GetClientUpgradeLevel(attacker, UPGRADE_SHORTNAME);

	char sBuf[32];
	hEvent.GetString("weapon", sBuf, sizeof sBuf);
	if(strcmp(sBuf, "hegrenade"))
	{
		return;
	}

	if(IsPlayerAlive(iClient) && IsPlayerAlive(iClient) && iLevel > 0 &&  iClient != attacker && iClient && attacker)
	{	
		if(g_DebugMode >= 1.0)
		{
			PrintToChatAll("Your weapon name in config should be %s", sBuf);
		}

		float fDmgIncreasePercent = GetWeaponChance(sBuf), chance;
				
		if (fDmgIncreasePercent >= 0.0 && fDmgIncreasePercent <= 100.0)
		{
			chance = iLevel * fDmgIncreasePercent;
		}
		else
		{
			chance = iLevel * g_hBingoChance;
		}

		float rnd = GetRandomFloat(1.0,300.0);

		DataPack hPack;
		Handle e = FindPluginByFile("smrpg/upgrades/smrpg_upgrade_antibingo.smx"); 
		if (e != INVALID_HANDLE)
		{
			if(SMRPG_IsUpgradeActiveOnClient(iClient, UPGRADE_SHORTNAME_anti))
			{
				int Abingo = Get_bingo(1), antilevel = SMRPG_GetClientUpgradeLevel(iClient, UPGRADE_SHORTNAME_anti), anti = Abingo * antilevel;

				chance -= anti;
				if(chance >= rnd)
				{
					CreateDataTimer(0.1, OnTakeDamage, hPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					hPack.WriteCell(iClient);
					hPack.WriteCell(attacker);
				}
			}
			else
			{
				if(chance >= rnd)
				{
					CreateDataTimer(0.1, OnTakeDamage, hPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					hPack.WriteCell(iClient);
					hPack.WriteCell(attacker);
				}
			}
		}
		else
		{
			if(chance >= rnd)
			{
				CreateDataTimer(0.1, OnTakeDamage, hPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				hPack.WriteCell(iClient);
				hPack.WriteCell(attacker);
			}
		}
	}
}

public void OnPluginEnd()
{
	if(SMRPG_UpgradeExists(UPGRADE_SHORTNAME))
		SMRPG_UnregisterUpgradeType(UPGRADE_SHORTNAME);
}

public void OnAllPluginsLoaded()
{
	OnLibraryAdded("smrpg");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "smrpg"))
	{
		SMRPG_RegisterUpgradeType("bingo", UPGRADE_SHORTNAME, "Give a small chance for kill player.", 10, true, 5, 15, 10);
		SMRPG_SetUpgradeTranslationCallback(UPGRADE_SHORTNAME, SMRPG_TranslateUpgrade);

		SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_bingo_chance", "1.0", "Chance for bingo(Level*Value).");
		ConVar hBingoChance = SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_bingo_chance", "1.0", "Chance for bingo(Level*Value).");
		hBingoChance.AddChangeHook(OnChanceChange);
		g_hBingoChance = hBingoChance.FloatValue;

		SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_debug_enable", "0.0", "Debug mode which is showing your correct weapon name(0.0 - disable/1.0-enable).");
		ConVar DebugMode = SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_debug_enable", "0.0", "Debug mode which is showing your correct weapon name(0.0 - disable/1.0-enable).");
		DebugMode.AddChangeHook(OnDebugChange);
		g_DebugMode = DebugMode.FloatValue;
	}
}

public void OnChanceChange(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	g_hBingoChance = hCvar.FloatValue;
}

public void OnDebugChange(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	g_DebugMode = hCvar.FloatValue;
}

public void SMRPG_TranslateUpgrade(int client, const char[] shortname, TranslationType type, char[] translation, int maxlen)
{
	if(type == TranslationType_Name)
		Format(translation, maxlen, "%T", UPGRADE_SHORTNAME, client);
	else if(type == TranslationType_Description)
	{
		char sDescriptionKey[MAX_UPGRADE_SHORTNAME_LENGTH+12] = UPGRADE_SHORTNAME;
		StrCat(sDescriptionKey, sizeof(sDescriptionKey), " description");
		Format(translation, maxlen, "%T", sDescriptionKey, client);
	}
}

bool LoadWeaponConfig()
{
	g_hWeaponDamage.Clear();
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/smrpg/bingo_weapons.cfg");
	
	if(!FileExists(sPath))
		return false;
	
	KeyValues hKV = new KeyValues("BingoWeapons");
	if(!hKV.ImportFromFile(sPath))
	{
		delete hKV;
		return false;
	}
	
	char sWeapon[64];
	if(hKV.GotoFirstSubKey(false))
	{
		int eInfo[WeaponConfig];
		do
		{
			hKV.GetSectionName(sWeapon, sizeof(sWeapon));
			
			eInfo[Weapon_Chance] = hKV.GetFloat("bingo_chance", -1.0);
			
			g_hWeaponDamage.SetArray(sWeapon, eInfo[0], view_as<int>(WeaponConfig));
			
		} 
		while (hKV.GotoNextKey());
	}
	
	delete hKV;
	return true;
}

float GetWeaponChance(const char[] sWeapon)
{
	int eInfo[WeaponConfig];
	if (g_hWeaponDamage.GetArray(sWeapon, eInfo[0], view_as<int>(WeaponConfig)))
	{
		if (eInfo[Weapon_Chance] >= 0.0)
		{
			return eInfo[Weapon_Chance];
		}
	}
	
	return 101.0;
}

Action OnTakeDamage(Handle hTimer, DataPack hPack)
{
	hPack.Reset();

	int client = hPack.ReadCell();
	int attacker = hPack.ReadCell();

	if(IsClientInGame(client) && !IsClientSourceTV(client)  && IsPlayerAlive(client) && IsPlayerAlive(attacker) && IsClientInGame(attacker) && !IsClientSourceTV(attacker))
	{
		SDKHooks_TakeDamage(client, attacker, attacker, float(GetClientHealth(client) + GetClientArmor(client))); 
		PrintToChatAll("Игрок: %N казнил игрока: %N", attacker , client);
	}
	return Plugin_Stop;
} 