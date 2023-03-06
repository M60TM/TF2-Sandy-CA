#pragma semicolon 1
#include <sourcemod>

#include <tf2_stocks>
#include <sdktools>

#pragma newdecls required

#include <stocksoup/tf/entity_prop_stocks>
#include <tf_custom_attributes>
#include <tf2attributes>

Handle g_SDKCallFirePipeBomb;
Handle g_SDKCallInitGrenade;

public void OnPluginStart() {
    Handle hGameConf = LoadGameConfigFile("tf2.cattr_pipebomb");
    if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.cattr_pipebomb).");
	}
    
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFWeaponBaseGun::FirePipeBomb()");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
    g_SDKCallFirePipeBomb = EndPrepSDKCall();
    
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"CTFWeaponBaseGrenadeProj::InitGrenade(int float)");
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
    g_SDKCallInitGrenade = EndPrepSDKCall();
    
    delete hGameConf;
}

public void OnMapStart() {
    HookEvent("player_death", OnPlayerDeath);
}

void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidClient(client))
    {
        return;
    }
    if (TF2_GetPlayerClass(client) != TFClass_DemoMan)
    {
        return;
    }

    int grenadelauncher = GetPlayerWeaponSlot(client, 0);
    if (IsValidEntity(grenadelauncher) && TF2CustAttr_GetInt(grenadelauncher, "grenade on death"))
    {
        SpawnGrenade(client, grenadelauncher, TF2CustAttr_GetInt(grenadelauncher, "grenade on death"));
    }
}

void SpawnGrenade(int client, int weapon, int num)
{
    for(int i = 0; i < num ; i++)
    {
        int PipeBomb = SDKCall(g_SDKCallFirePipeBomb, weapon, client, 0);

        float angBaseAim[3], vecFwdBaseAim[3];
        vecFwdBaseAim[0] = float(GetRandomInt(-100, 100));
        vecFwdBaseAim[1] = float(GetRandomInt(-100, 100));
        vecFwdBaseAim[2] = float(GetRandomInt(25, 100));
        float radius = TF2Attrib_HookValueFloat(146.0, "mult_explosion_radius", weapon);
        SDKCall(g_SDKCallInitGrenade, PipeBomb, vecFwdBaseAim, angBaseAim, client, 100, radius);

        float vecSrc[3];
        GetClientAbsOrigin(client, vecSrc);
        TeleportEntity(PipeBomb, vecSrc, angBaseAim, vecFwdBaseAim);
    }
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}