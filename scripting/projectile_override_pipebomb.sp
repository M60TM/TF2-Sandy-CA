#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <dhooks>

#pragma newdecls required

#include <stocksoup/tf/entity_prop_stocks>
#include <stocksoup/tf/weapon>
#include <tf_custom_attributes>
#include <tf2attributes>

Handle g_SDKCallFirePipeBomb;
Handle g_SDKCallGetProjectileFireSetup;
Handle g_SDKCallInitGrenade;

public Plugin myinfo = {
	name = "[TF2] Custom Attribute: Projectile Override Pipebomb",
	author = "Sandy",
	description = "",
	version = "1.0.0",
	url = "https://github.com/M60TM/TF2-Sandy-CA"
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.cattr_pipebomb");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.cattr_pipebomb).");
	}
	
	Handle dtBaseGunFireProjectile = DHookCreateFromConf(hGameConf,
			"CTFWeaponBaseGun::FireProjectile()");
	DHookEnableDetour(dtBaseGunFireProjectile, false, OnBaseGunFireProjectilePre);
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFWeaponBaseGun::FirePipeBomb()");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKCallFirePipeBomb = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"CTFWeaponBase::GetProjectileFireSetup()");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	{
		// work around SM1.10 bug #1059
		// https://github.com/alliedmodders/sourcemod/issues/1059
		// PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	}
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer,
			.encflags = VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_Pointer,
			.encflags = VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_SDKCallGetProjectileFireSetup = EndPrepSDKCall();

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

MRESReturn OnBaseGunFireProjectilePre(int weapon, Handle hParams) {
	int owner = TF2_GetEntityOwner(weapon);
	if (owner < 1 || owner > MaxClients) {
		return MRES_Ignored;
	}
	
	char buffer[128];
	if (!TF2CustAttr_GetString(weapon, "override projectile pipebomb",
			buffer, sizeof(buffer))) {
		return MRES_Ignored;
	}
	
	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (!clip) {
		return MRES_Supercede;
	}
	
	float vecOffset[3], vecSrc[3];
	vecOffset[0] = 23.5;
	vecOffset[1] = 12.0;
	vecOffset[2] = GetEntityFlags(owner) & FL_DUCKING? 12.0 : 1.0;
	
	float angBaseAim[3], vecFwdBaseAim[3];
	SDKCall(g_SDKCallGetProjectileFireSetup, weapon, owner, vecOffset[0], vecOffset[1],
			vecOffset[2], vecSrc, angBaseAim, false, 1216.0);
	GetAngleVectors(angBaseAim, vecFwdBaseAim, NULL_VECTOR, NULL_VECTOR);
	
	ScaleVector(vecFwdBaseAim,
			TF2Attrib_HookValueFloat(1216.0, "mult_projectile_speed", weapon));
	
	// base damage is based on weapon
	int PipeBomb = SDKCall(g_SDKCallFirePipeBomb, weapon, owner, 0);

	float radius = TF2Attrib_HookValueFloat(146.0, "mult_explosion_radius", weapon);
	SDKCall(g_SDKCallInitGrenade, PipeBomb, vecFwdBaseAim, angBaseAim, owner, 100, radius);

	TeleportEntity(PipeBomb, vecSrc, angBaseAim, vecFwdBaseAim);
	
	SetEntProp(weapon, Prop_Data, "m_iClip1", clip - 1);
	
	// TF2_SetWeaponAmmo(weapon, TF2_GetWeaponAmmo(weapon) - 1);
	return MRES_Supercede;
}
