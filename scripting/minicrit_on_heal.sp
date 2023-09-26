#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <dhooks_gameconf_shim>
#include <tf2_stocks>

#pragma newdecls required

#include <stocksoup/tf/entity_prop_stocks>

#include <tf2utils>
#include <tf_custom_attributes>

DynamicHook g_DHookUpdateOnRemove;

public Plugin myinfo = {
	name = "[TF2] Minicrit on Heal",
	author = "Sandy and nosoop",
	description = "Give minicrit to your patient",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData data = new GameData("Shared_Healing");
	if (data == null) {
		SetFailState("Failed to load gamedata (Shared_Healing).");
	} else if (!ReadDHooksDefinitions("Shared_Healing")) {
		SetFailState("Failed to read DHooks definitions (Shared_Healing).");
	}
	
	DynamicDetour dynDetourSharedStartHealing = GetDHooksDetourDefinition(data, "CTFPlayerShared::Heal()");
	dynDetourSharedStartHealing.Enable(Hook_Post, Detour_SharedStartHealing);
	
	DynamicDetour dynDetourSharedStopHealing = GetDHooksDetourDefinition(data, "CTFPlayerShared::StopHealing()");
	dynDetourSharedStopHealing.Enable(Hook_Post, Detour_SharedStopHealing);
	
	g_DHookUpdateOnRemove = GetDHooksHookDefinition(data, "CBaseEntity::UpdateOnRemove()");
	if (!g_DHookUpdateOnRemove) {
		SetFailState("Failed to create detour %s", "CBaseEntity::UpdateOnRemove()");
	}
	
	ClearDHooksDefinitions();
	delete data;
}

public void OnMapStart() {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		if (TF2Util_IsEntityWeapon(entity) && TF2Util_GetWeaponID(entity) == TF_WEAPON_MEDIGUN) {
			DHookEntity(g_DHookUpdateOnRemove, false, entity, .callback = OnMedigunRemoved);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (TF2Util_IsEntityWeapon(entity) && TF2Util_GetWeaponID(entity) == TF_WEAPON_MEDIGUN) {
		DHookEntity(g_DHookUpdateOnRemove, false, entity, .callback = OnMedigunRemoved);
	}
}

MRESReturn OnMedigunRemoved(int medigun) {
	if (!TF2CustAttr_GetInt(medigun, "minicrit on heal")) {
		return MRES_Ignored;
	}
	
	int owner = TF2_GetEntityOwner(medigun);
	if (1 <= owner <= MaxClients) {
		int patient = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		if (patient < 1 || patient > MaxClients || !IsClientInGame(patient)) {
			return MRES_Ignored;
		}
		
		if (TF2_IsPlayerInCondition(patient, TFCond_Buffed) && TF2Util_GetPlayerConditionProvider(patient, TFCond_Buffed) == owner) {
			TF2_RemoveCondition(patient, TFCond_Buffed);
		}
	}
	
	return MRES_Ignored;
}

MRESReturn Detour_SharedStartHealing(Address shared, DHookParam params) {
	if (params.Get(5)) {
		return MRES_Ignored;
	}
	
	int owner = params.Get(1);
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner)) {
		return MRES_Ignored;
	}
	
	int medigun = GetPlayerWeaponSlot(owner, 1);
	if (!IsValidEntity(medigun)) {
		return MRES_Ignored;
	}
	
	if (!TF2CustAttr_GetInt(medigun, "minicrit on heal")) {
		return MRES_Ignored;
	}
	
	int patient = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
	if (patient < 1 || patient > MaxClients || !IsClientInGame(patient)) {
		return MRES_Ignored;
	}
	
	TF2_AddCondition(patient, TFCond_Buffed, _, owner);
	
	return MRES_Ignored;
}

MRESReturn Detour_SharedStopHealing(Address shared, DHookParam params) {
	int patient = TF2Util_GetPlayerFromSharedAddress(shared);
	if (patient < 1 || patient > MaxClients || !IsClientInGame(patient)) {
		return MRES_Ignored;
	}
	
	int owner = params.Get(1);
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner)) {
		return MRES_Ignored;
	}
	
	int medigun = GetPlayerWeaponSlot(owner, 1);
	if (!IsValidEntity(medigun)) {
		return MRES_Ignored;
	}
	
	if (!TF2CustAttr_GetInt(medigun, "minicrit on heal")) {
		return MRES_Ignored;
	}
	
	if (TF2_IsPlayerInCondition(patient, TFCond_Buffed) && TF2Util_GetPlayerConditionProvider(patient, TFCond_Buffed) == owner) {
		TF2_RemoveCondition(patient, TFCond_Buffed);
	}
	
	return MRES_Ignored;
}