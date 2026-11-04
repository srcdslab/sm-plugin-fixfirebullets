#include <sourcemod>
#include <dhooks>
#pragma semicolon 1
#pragma newdecls required

DynamicHook g_hWeapon_ShootPosition;
Handle g_hWeapon_ShootPosition_SDKCall = null;
float g_vecOldWeaponShootPos[MAXPLAYERS + 1][3];
bool g_bInUserCmd[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Bullet position fix",
	author = "xutaxkamay",
	description = "Fixes shoot position",
	version = "1.2.4",
	url = "https://forums.alliedmods.net/showthread.php?p=2646571"
};

public void OnPluginStart()
{
	GameData gameData = new GameData("firebulletsfix.games");

	if (!gameData)
		SetFailState("[FireBullets Fix] No game data present");

	int offset = gameData.GetOffset("Weapon_ShootPosition");

	if (offset == -1)
		SetFailState("[FireBullets Fix] failed to find offset");

	LogMessage("Found offset for Weapon_ShootPosition %d", offset);

	// CS:S does not override CBasePlayer::Weapon_ShootPosition(), which returns EyePosition(). GetClientEyePosition()
	// ends up there too (ClientEarPosition -> EarPosition -> EyePosition) and is much cheaper than an SDKCall, which
	// also goes through our own hook. Other games can override Weapon_ShootPosition() (CS:GO adds the animation
	// state eye offset), so they keep the SDKCall
	if (GetEngineVersion() != Engine_CSS)
	{
		StartPrepSDKCall(SDKCall_Player);

		if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "Weapon_ShootPosition"))
			SetFailState("[FireBullets Fix] couldn't read config for preparing Weapon_ShootPosition SDKCall");

		PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
		g_hWeapon_ShootPosition_SDKCall = EndPrepSDKCall();

		if (g_hWeapon_ShootPosition_SDKCall == null)
			SetFailState("[FireBullets Fix] couldn't prepare Weapon_ShootPosition SDKCall");
	}

	g_hWeapon_ShootPosition = new DynamicHook(offset, HookType_Entity, ReturnType_Vector, ThisPointer_CBaseEntity);

	if (!g_hWeapon_ShootPosition)
		SetFailState("[FireBullets Fix] couldn't hook Weapon_ShootPosition");

	delete gameData;

	for (int client = 1; client <= MaxClients; client++)
		OnClientPutInServer(client);
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
		g_hWeapon_ShootPosition.HookEntity(Hook_Post, client, Weapon_ShootPosition_Post);
}

public Action OnPlayerRunCmd(int client)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	// Closed while we read the position, so the SDKCall gets the real one from our hook
	g_bInUserCmd[client] = false;

	if (g_hWeapon_ShootPosition_SDKCall == null)
		GetClientEyePosition(client, g_vecOldWeaponShootPos[client]);
	else
		SDKCall(g_hWeapon_ShootPosition_SDKCall, client, g_vecOldWeaponShootPos[client]);

	// Weapons fire in PostThink, after this command's movement. Until OnPlayerRunCmdPost,
	// Weapon_ShootPosition returns the position the player aimed from
	g_bInUserCmd[client] = true;
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client)
{
	g_bInUserCmd[client] = false;
}

public MRESReturn Weapon_ShootPosition_Post(int client, DHookReturn hReturn)
{
	// Outside the player's own command (weapon drop from the drop command or when killed by another
	// player, other plugins), the stored position is stale: keep the real one
	if (!g_bInUserCmd[client])
		return MRES_Ignored;

	#if defined DEBUG
	float g_vecWeaponShootPos[3];
	hReturn.GetVector(g_vecWeaponShootPos);
	PrintToConsoleAll("[FireBullets Fix] Old Weapon_ShootPosition: %.2f, %.2f, %.2f", g_vecOldWeaponShootPos[client][0], g_vecOldWeaponShootPos[client][1], g_vecOldWeaponShootPos[client][2]);
	PrintToConsoleAll("[FireBullets Fix] New Weapon_ShootPosition: %.2f, %.2f, %.2f", g_vecWeaponShootPos[0], g_vecWeaponShootPos[1], g_vecWeaponShootPos[2]);
	#endif
	hReturn.SetVector(g_vecOldWeaponShootPos[client]);
	return MRES_Supercede;
}

stock bool IsValidClient(int client)
{
	return ((0 < client <= MaxClients) && IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client) && !IsClientSourceTV(client) && !IsClientReplay(client));
}
