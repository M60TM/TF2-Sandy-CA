#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks_gameconf_shim>

#pragma newdecls required

#include <stocksoup/tf/entity_prop_stocks>

#include <tf_custom_attributes>

DynamicHook g_DHookMeleeSmack;
DynamicHook g_DHookMeleeDeflectProjectiles;
Handle g_SDKCallDeflectProjectiles;

public Plugin myinfo = {
	name = "[TF2] Melee Airblast",
	author = "Sandy",
	description = "Deflect projectiles by hitting them",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData data = new GameData("Melee_Airblast");
	if (data == null) {
		SetFailState("Failed to load gamedata (Melee_Airblast).");
	} else if (!ReadDHooksDefinitions("Melee_Airblast")) {
		SetFailState("Failed to read DHooks definitions (Melee_Airblast).");
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "CTFWeaponBase::DeflectProjectiles");
	g_SDKCallDeflectProjectiles = EndPrepSDKCall();
	
	g_DHookMeleeSmack = GetDHooksHookDefinition(data, "CTFWeaponBaseMelee::Smack");
	g_DHookMeleeDeflectProjectiles = GetDHooksHookDefinition(data, "CTFWeaponBase::DeflectEntity");
	
	ClearDHooksDefinitions();
	delete data;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (IsValidEntity(entity) && IsWeaponBaseMelee(entity)) {
		g_DHookMeleeSmack.HookEntity(Hook_Post, entity, DHook_MeleeSmackPost);
		g_DHookMeleeDeflectProjectiles.HookEntity(Hook_Pre, entity, DHook_MeleeDeflectProjectilesPre);
	}
}

MRESReturn DHook_MeleeSmackPost(int entity) {
	if (TF2CustAttr_GetInt(entity, "melee airblast")) {
		SDKCall(g_SDKCallDeflectProjectiles, entity);
	}
	
	return MRES_Ignored;
}

// Fix Deflect Friendly Team's Projectile
MRESReturn DHook_MeleeDeflectProjectilesPre(int entity, DHookReturn ret, DHookParam params) {
	int projectile = params.Get(1);
	if (IsValidEntity(projectile) && HasEntProp(projectile, Prop_Send, "m_iTeamNum")) {
		int owner = TF2_GetEntityOwner(entity);
		if (IsValidClient(owner) && GetClientTeam(owner) == GetEntProp(projectile, Prop_Send, "m_iTeamNum")) {
			ret.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

bool IsWeaponBaseMelee(int entity) {
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

stock bool IsValidClient(int client, bool replaycheck=true) {
	if (client < 1 || client > MaxClients) {
		return false;
	}
	
	if (!IsClientInGame(client)) {
		return false;
	}
	
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) {
		return false;
	}
	
	if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client))) {
		return false;
	}
	
	return true;
}