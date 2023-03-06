#include <sdkhooks>
#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <stocksoup/tf/entity_prop_stocks>
#include <tf_custom_attributes>

Handle g_SDKCallGrenadeDetonade;

Handle g_DHookVPhysicsCollision;

public Plugin myinfo = {
	name = "[TF2] Custom Attribute: Detonade on Touch",
	author = "Sandy",
	description = "",
	version = "1.0.0",
	url = "https://github.com/M60TM/TF2-Sandy-CA"
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("tf2.cattr_pipebomb");
	if (!hGameConf)
	{
		SetFailState("Failed to load gamedata (tf2.cattr_pipebomb).")
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFWeaponBaseGrenadeProj::Detonate");
	g_SDKCallGrenadeDetonade = EndPrepSDKCall();
	if (!(g_SDKCallGrenadeDetonade = EndPrepSDKCall()))
		SetFailState("Could not load call to CTFWeaponBaseGrenadeProj::Detonate");
	
	g_DHookVPhysicsCollision = DHookCreateFromConf(hGameConf, "CTFGrenadePipebombProjectile::VPhysicsCollision");
	
	delete hGameConf;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_projectile_pipe") == 0)
	{
		DHookEntity(g_DHookVPhysicsCollision, true, iEntity, .callback = Tags_OnProjectileTouch);
	}
}

public MRESReturn Tags_OnProjectileTouch(int iProjectile)
{
	int iWeapon = GetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher");
	
	if (IsValidEntity(iWeapon))
	{
        if (TF2CustAttr_GetInt(iWeapon, "detonade on touch"))
		{
            SDKCall(g_SDKCallGrenadeDetonade, EntIndexToEntRef(iProjectile));
		}
	}
	
	return MRES_Ignored;
}