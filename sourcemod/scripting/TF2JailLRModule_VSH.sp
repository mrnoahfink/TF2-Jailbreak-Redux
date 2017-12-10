#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2items>
#include <morecolors>
#include <tf2_stocks>
#include <tf2attributes>
#include "include/smlib/clients.inc"
#include <tf2jailredux>
#pragma semicolon 1
#pragma newdecls required

#define UNASSIGNED 			0
#define NEUTRAL 			0
#define SPEC 				1
#define RED 				2
#define BLU 				3

#define int(%1)				view_as<int>(%1)
#define Handle(%1)			view_as<Handle>(%1)

#define nullfunc			INVALID_FUNCTION
#define nullvec				NULL_VECTOR
#define nullstr				NULL_STRING
#define toggle(%1)			%1 = !%1

#define _buffer(%1)			%1, sizeof(%1)
#define _strbuffer(%1)			%1, sizeof(%1)
#define PLYR				MAXPLAYERS+1
#define PATH				64
#define FULLPATH			PLATFORM_MAX_PATH
#define repeat(%1)			for (int xyz=0; xyz<%1; ++xyz)
#define FULLTIMER			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
#define HALFTIMER1			TIMER_REPEAT
#define HALFTIMER2			TIMER_FLAG_NO_MAPCHANGE

#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION		"1.0.0"

methodmap JailBoss < JBPlayer
{	// Here we inherit all of the properties and functions that we made as natives
	public JailBoss (const int q, bool userid=false)
	{ return view_as< JailBoss >( JBPlayer(q, userid) ); }

	property int iUberTarget 
	{	// And then add new ones that we need
		public get() 				{ return this.GetProperty("iUberTarget"); }
		public set(const int i) 	{ this.SetProperty("iUberTarget", i); }
	}
	property int iHealth 
	{
		public get() 				{ return this.GetProperty("iHealth"); }
		public set(const int i) 	{ this.SetProperty("iHealth", i); }
	}
	property int iMaxHealth 
	{
		public get() 				{ return this.GetProperty("iMaxHealth"); }
		public set(const int i) 	{ this.SetProperty("iMaxHealth", i); }
	}
	property int iAirDamage 
	{
		public get() 				{ return this.GetProperty("iAirDamage"); }
		public set(const int i) 	{ this.SetProperty("iAirDamage", i); }
	}
	property int iType 
	{
		public get() 				{ return this.GetProperty("iType"); }
		public set(const int i) 	{ this.SetProperty("iType", i); }
	}
	property int iStabbed 
	{
		public get() 				{ return this.GetProperty("iStabbed"); }
		public set(const int i) 	{ this.SetProperty("iStabbed", i); }
	}
	property int iMarketted 
	{
		public get() 				{ return this.GetProperty("iMarketted"); }
		public set(const int i) 	{ this.SetProperty("iMarketted", i); }
	}
	property int iDamage 
	{
		public get() 				{ return this.GetProperty("iDamage"); }
		public set(const int i) 	{ this.SetProperty("iDamage", i); }
	}
	property int bGlow 
	{
		public get() 				{ return this.GetProperty("bGlow"); }
		public set(const int i) 	{ this.SetProperty("bGlow", i); }
	}
	property int iKills 
	{
		public get() 				{ return this.GetProperty("iKills"); }
		public set(const int i) 	{ this.SetProperty("iKills", i); }
	}
	property int iClimbs 
	{
		public get() 				{ return this.GetProperty("iClimbs"); }
		public set(const int i) 	{ this.SetProperty("iClimbs", i); }
	}

	property bool bIsBoss 
	{
		public get() 				{ return this.GetProperty("bIsBoss"); }
		public set(const bool i) 	{ this.SetProperty("bIsBoss", i); }
	}
	/*property bool bInJump 	// Moved to core
	{
		public get() 				{ return this.GetProperty("bInJump"); }
		public set(const bool i) 	{ this.SetProperty("bInJump", i); }
	}*/

	/*property float flSpeed 	// Moved to core
	{
		public get() 				{ return this.GetProperty("flSpeed"); }
		public set(const float i) 	{ this.SetProperty("flSpeed", i); }
	}*/
	property float flRAGE 
	{
		public get() 				{ return this.GetProperty("flRAGE"); }
		public set(const float i) 	{ this.SetProperty("flRAGE", i); }
	}
	property float flWeighDown 
	{
		public get() 				{ return this.GetProperty("flWeighDown"); }
		public set(const float i) 	{ this.SetProperty("flWeighDown", i); }
	}
	property float flGlowtime 
	{
		public get() 				{ return this.GetProperty("flGlowtime"); }
		public set(const float i) 	{ this.SetProperty("flGlowtime", i); }
	}
	property float flCharge 
	{
		public get() 				{ return this.GetProperty("flCharge"); }
		public set(const float i) 	{ this.SetProperty("flCharge", i); }
	}
	property float flKillSpree 
	{
		public get() 				{ return this.GetProperty("flKillSpree"); }
		public set(const float i) 	{ this.SetProperty("flKillSpree", i); }
	}

	public void ConvertToBoss(const int bossid)
	{	// Happens directly on round start, given to a random player
		this.iType = bossid;	// I wanted to set up a queue system like regular VSH but meh effort
		this.bIsBoss = true;
		this.flRAGE = 0.0;
		SetPawnTimer(_MakePlayerBoss, 0.1, this.userid);
	}
	public void GiveRage(const int damage)
	{	// On player_hurt
		this.flRAGE += ( damage/SquareRoot(30000.0)*4.0 );
	}
	public void ClimbWall(const int weapon, const float upwardvel, const float health, const bool attackdelay)
	//Credit to Mecha the Slag
	{
		if ( GetClientHealth(this.index) <= health )	// Have to baby players so they don't accidentally kill themselves trying to escape
			return;

		int client = this.index;
		char classname[64];
		float vecClientEyePos[3];
		float vecClientEyeAng[3];
		GetClientEyePosition(client, vecClientEyePos);   // Get the position of the player's eyes
		GetClientEyeAngles(client, vecClientEyeAng);	   // Get the angle the player is looking

		// Check for colliding entities
		TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);

		if ( !TR_DidHit(null) )
			return;

		int TRIndex = TR_GetEntityIndex(null);
		GetEdictClassname(TRIndex, classname, sizeof(classname));
		if (!StrEqual(classname, "worldspawn"))
			return;

		float fNormal[3];
		TR_GetPlaneNormal(null, fNormal);
		GetVectorAngles(fNormal, fNormal);

		if (fNormal[0] >= 30.0 && fNormal[0] <= 330.0)
			return;
		if (fNormal[0] <= -30.0)
			return;

		float pos[3]; TR_GetEndPosition(pos);
		float distance = GetVectorDistance(vecClientEyePos, pos);

		if (distance >= 100.0)
			return;

		float fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
		fVelocity[2] = upwardvel;

		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		SDKHooks_TakeDamage(client, client, client, health, DMG_CLUB, GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));

		if (attackdelay)
			SetPawnTimer(NoAttacking, 0.1, EntIndexToEntRef(weapon));
	}
	public void Init_VSH()
	{
		this.bIsBoss = false;
		this.iType = -1;
		this.iStabbed = 0;
		this.iMarketted = 0;
		this.flRAGE = 0.0;
		this.iDamage = 0;
		this.iAirDamage = 0;
		this.iUberTarget = 0;
		this.flCharge = 0.0;
		this.bGlow = 0;
		this.flGlowtime = 0.0;
		SetEntityRenderColor(this.index, 255, 255, 255, 255);
		this.iHealth = 0;
		this.iMaxHealth = 0;
	}
};

public Plugin myinfo =
{
	name = "TF2Jail VSH LR Module",
	author = "Ragenewb, just about all probs to Nergal/Assyrian",
	description = "Versus Saxton Hale embedded as an LR for TF2Jail Redux",
	version = PLUGIN_VERSION,
	url = ""
};

enum/*CvarName*/
{
	EnableMusic = 0,
	DamagePoints, 
	MusicVolume, 
	MedigunReset, 
	StopTickleTime, 
	AirStrikeDamage, 
	AirblastRage, 
	JarateRage, 
	FanoWarRage, 
	EngieBuildings, 
	PermOverheal,
	DemoShieldCrits, 
	DroppedWeapons, 
	Anchoring, 
	Version
};

ConVar
bEnabled = null
;

ConVar JBVSH[Version + 1];

Handle hHudText, 
	   rageHUD, 
	   //MusicCookie,
	   jumpHUD
;

int iHealthChecks = 0;		// For !halehp

float flHealthTime = 0.0,	// For health bar
	  flMusicTime = 0.0;	// Playing the background songs 

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_jbvsh_enabled", "1", "Enable TF2Jail VSH Sub-Plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	JBVSH[Version] = CreateConVar("jbvsh_version", PLUGIN_VERSION, "Versus Saxton Hale Version (Do not touch)", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	JBVSH[EnableMusic] = CreateConVar("sm_jbvsh_enable_music", "1", "Enable or disable background music.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	JBVSH[MusicVolume] = CreateConVar("sm_jbvsh_music_volume", "0.5", "How loud the background music should be, if enabled.", FCVAR_NOTIFY, true, 0.0, true, 20.0);
	JBVSH[DamagePoints] = CreateConVar("sm_jbvsh_damage_points", "600", "Amount of damage needed to gain 1 point on the scoreboard.", FCVAR_NOTIFY, true, 1.0);
	JBVSH[MedigunReset] = CreateConVar("sm_jbvsh_medigun_reset_amount", "0.31", "How much Uber percentage should Mediguns, after Uber, reset to?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	JBVSH[StopTickleTime] = CreateConVar("sm_jbvsh_stop_tickle_time", "3.0", "How long in seconds the tickle effect from the Holiday Punch lasts before being removed.", FCVAR_NOTIFY, true, 0.01);
	JBVSH[AirStrikeDamage] = CreateConVar("sm_jbvsh_airstrike_damage", "200", "How much damage needed for the Airstrike to gain +1 clipsize.", FCVAR_NOTIFY);
	JBVSH[AirblastRage] = CreateConVar("sm_jbvsh_airblast_rage", "8.0", "How much Rage should airblast give/remove? (negative number to remove rage)", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	JBVSH[JarateRage] = CreateConVar("sm_jbvsh_jarate_rage", "8.0", "How much rage should Jarate give/remove? (negative number to add rage)", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	JBVSH[FanoWarRage] = CreateConVar("sm_jbvsh_fanowar_rage", "5.0", "How much rage should the Fan o' War give/remove? (negative number to add rage)", FCVAR_NOTIFY);
	JBVSH[EngieBuildings] = CreateConVar("sm_jbvsh_killbuilding_engiedeath", "1", "If 0, no building dies when engie dies. If 1, only sentry dies. If 2, all buildings die.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	JBVSH[PermOverheal] = CreateConVar("sm_jbvsh_permanent_overheal", "0", "If enabled, Mediguns give permanent overheal.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	JBVSH[DemoShieldCrits] = CreateConVar("sm_jbvsh_demoman_shield_crits", "1", "Sets Demoman Shield crit behaviour. 0 - No crits, 1 - Mini-crits, 2 - Crits, 3 - Scale with Charge Meter (Losing the Shield results in no more (mini)crits.)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	JBVSH[Anchoring] = CreateConVar("sm_jbvsh_allow_boss_anchor", "1", "When enabled, reduces all knockback bosses experience when crouching.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_hale_hp", Command_GetHPCmd);
	RegConsoleCmd("sm_halehp", Command_GetHPCmd);
	RegConsoleCmd("sm_boss_hp", Command_GetHPCmd);
	RegConsoleCmd("sm_bosshp", Command_GetHPCmd);
	RegConsoleCmd("sm_ff2_hp", Command_GetHPCmd);
	RegConsoleCmd("sm_ff2hp", Command_GetHPCmd);

	AddCommandListener(BlockSuicide, "explode");
	AddCommandListener(BlockSuicide, "kill");
	AddCommandListener(BlockSuicide, "jointeam");

	hHudText = CreateHudSynchronizer();
	rageHUD = CreateHudSynchronizer();
	jumpHUD = CreateHudSynchronizer();
	
	AutoExecConfig(true, "LRModuleVSH");

	AddCommandListener(DoTaunt, "taunt");
	AddCommandListener(DoTaunt, "+taunt");
	AddCommandListener(cdVoiceMenu, "voicemenu");
	AddNormalSoundHook(HookSound);

	AddMultiTargetFilter("@boss", HaleTargetFilter, "the current Boss/Bosses", false);
	AddMultiTargetFilter("@hale", HaleTargetFilter, "the current Boss/Bosses", false);
	AddMultiTargetFilter("@!boss", HaleTargetFilter, "all non-Boss players", false);
	AddMultiTargetFilter("@!hale", HaleTargetFilter, "all non-Boss players", false);


	//LoadJBHooks();
	//CheckJBHooks();
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerKilled, EventHookMode_Pre);
}
/** Loading LR sub-plugins HAS TO HAPPEN OnAllPluginsLoaded() to assure that TF2Jail_Redux loads first **/
//int JBVSHIndex;	// TODO, add a Forwards check to make sure proper sub-plugin is being hooked; hence the JBVSHIndex int
public void OnAllPluginsLoaded()
{
	TF2JailRedux_RegisterPlugin("LRModule_VSH");
	//LoadJBHooks();
	CheckJBHooks();	// Redundant, DEBUGGING
}

public bool HaleTargetFilter(const char[] pattern, Handle clients)
{
	bool non = StrContains(pattern, "!", false)!= - 1;
	for (int i = MaxClients; i; i--) 
	{
		if (IsClientValid(i) && FindValueInArray(clients, i) == - 1)
		{
			if (bEnabled.BoolValue && JailBoss(i).bIsBoss) 
			{
				if (!non)
					PushArrayCell(clients, i);
			}
			else if (non)
				PushArrayCell(clients, i);
		}
	}
	return true;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	JailBoss player = JailBoss(client);
	player.bIsBoss = false;
	player.iType = -1;
	player.iStabbed = 0;
	player.iMarketted = 0;
	player.flRAGE = 0.0;
	player.iDamage = 0;
	player.iAirDamage = 0;
	player.iUberTarget = 0;
	player.flCharge = 0.0;
	player.bGlow = 0;
	player.flGlowtime = 0.0;
	player.iHealth = 0;
	player.iMaxHealth = 0;
}
public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return Plugin_Continue;

	JailBoss vict = JailBoss(victim);
	int bFallDamage = (damagetype & DMG_FALL);
	if (vict.bIsBoss && attacker <= 0 && bFallDamage)
	{
		damage = (vict.iHealth > 100) ? 1.0 : 30.0;
		return Plugin_Changed;
	}
	if (!vict.bIsBoss && attacker <= 0 && bFallDamage && IsValidEntity(FindPlayerBack(victim, { 608, 405, 133, 444 }, 4))) 
	{
		damage /= 10.0;
		return Plugin_Changed;
	}

	if (vict.bIsBoss)
		return ManageOnBossTakeDamage(vict, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);

	if (!IsClientValid(attacker))
		return Plugin_Continue;

	JailBoss BossAttacker = JailBoss(attacker);
	if (BossAttacker.bIsBoss)
		return ManageOnBossDealDamage(vict, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);

	JailBoss(attacker).iDamage += damage;
	return Plugin_Continue;
}


public Action BlockSuicide(int client, const char[] command, int argc)
{
	if (bEnabled.BoolValue && JBGameMode_GetProperty("iRoundState") == StateRunning || JBGameMode_GetProperty("iLRType") != 13)
	{
		JailBoss player = JailBoss(client);
		if (player.bIsBoss) 
		{
			float flhp_percent = float(player.iHealth) / float(player.iMaxHealth);
			if (flhp_percent > 0.30) 
			{  // Allow bosses to suicide if their total health is under 30%.
				CPrintToChat(client, "{salmon}Nope.avi, you have to play.");
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if (JailBoss(client).bIsBoss && JBGameMode_GetProperty("iRoundState") >= StateRunning)
		CPrintToChatAll("{tan}[JailRedux]{fullred} Boss has disconnected!");
}

public void OnMapStart()
{
	CreateTimer(5.0, MakeModelTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	// Model isn't always set OnPlayerSpawned() so this'll do under certain circumstances
	CreateTimer(0.1, TimerChecker, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound("ui/item_store_add_to_cart.wav", true);
	PrecacheSound("player/doubledonk.wav", true);
	PrecacheSound("saxton_hale/9000.wav", true);
	CheckDownload("sound/saxton_hale/9000.wav");
	PrecacheSound("items/pumpkin_pickup.wav", true);
	AddHaleToDownloads();
	AddVagToDownloads();
	AddCBSToDownloads();
	AddHHHToDownloads();
	AddBunnyToDownloads();
}

public Action MakeModelTimer(Handle hTimer)
{
	if (!bEnabled.BoolValue || 	JBGameMode_GetProperty("iLRType") != 13)
		return Plugin_Continue;

	for (int i = MaxClients; i; --i) 
	{
		if (!IsClientValid(i))
			continue;
		JailBoss player = JailBoss(i);
		if (player.bIsBoss) 
		{
			if (!IsPlayerAlive(i))
				continue;
			ManageBossModels(player);
		}
	}
	return Plugin_Continue;
}

public Action TimerChecker(Handle hTimer)
{
	if (!bEnabled.BoolValue || 	JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return Plugin_Continue;

	if (flMusicTime <= GetGameTime())
		_MusicPlay();

	return Plugin_Continue;
}
public void SetGravityNormal(const int userid)
{
	int i = GetClientOfUserId(userid);
	if (IsClientValid(i))
		SetEntityGravity(i, 1.0);
}

public int HintPanel(Menu menu, MenuAction action, int param1, int param2)
{	// Boss help panel
	return;
}

public void _MakePlayerBoss(const int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client)) {
		JailBoss player = JailBoss(client);
		ManageBossTransition(player);
	}
}

public void OnPreThinkPost(int client)
{	// We don't want cheaters to camp near dispensers now do we?
	if (!bEnabled.BoolValue || 	JBGameMode_GetProperty("iLRType") != 13)
		return;

	if (IsClientObserver(client) || !IsPlayerAlive(client))
		return;
	
	if (IsNearSpencer(client)) 
	{
		if (TF2_IsPlayerInCondition(client, TFCond_Cloaked)) 
		{
			float cloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") - 0.5;
			if (cloak < 0.0)
				cloak = 0.0;
			SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", cloak);
		}
	}
	return;
}

public Action RemoveEntity(Handle timer, any entid)
{
	int ent = EntRefToEntIndex(entid);
	if (ent > 0 && IsValidEntity(ent))
		AcceptEntityInput(ent, "Kill");
	return Plugin_Continue;
}

public Action cdVoiceMenu(int client, const char[] command, int argc)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return Plugin_Continue;
	if (argc < 2 || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	char szCmd1[8]; GetCmdArg(1, szCmd1, sizeof(szCmd1));
	char szCmd2[8]; GetCmdArg(2, szCmd2, sizeof(szCmd2));
	
	// Capture call for medic commands (represented by "voicemenu 0 0")
	JailBoss player = JailBoss(client);
	if (szCmd1[0] == '0' && szCmd2[0] == '0' && player.bIsBoss)
		ManageBossMedicCall(player);
	
	return Plugin_Continue;
}

public Action DoTaunt(int client, const char[] command, int argc)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return Plugin_Continue;
	
	JailBoss player = JailBoss(client);
	if (player.flRAGE >= 100.0) 
	{
		ManageBossTaunt(player);
		player.flRAGE = 0.0;
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;
	
	ManageEntityCreated(entity, classname);
}

public void ShowPlayerScores()
{
	JailBoss hTop[3];
	
	JailBoss(0).iDamage = 0;
	JailBoss player;
	for (int i = MaxClients; i; --i) 
	{
		if (!IsClientValid(i))
			continue;
		
		player = JailBoss(i);
		if (player.bIsBoss) 
		{
			player.iDamage = 0;
			continue;
		}
		
		if (player.iDamage >= hTop[0].iDamage) 
		{
			hTop[2] = hTop[1];
			hTop[1] = hTop[0];
			hTop[0] = JailBoss(i);
		}
		else if (player.iDamage >= hTop[1].iDamage) 
		{
			hTop[2] = hTop[1];
			hTop[1] = JailBoss(i);
		}
		else if (player.iDamage >= hTop[2].iDamage)
			hTop[2] = JailBoss(i);
	}
	if (hTop[0].iDamage > 9000)
		SetPawnTimer(OverNineThousand, 1.0);
	
	char score1[PATH], score2[PATH], score3[PATH];
	if (IsValidClient(hTop[0].index) && (GetClientTeam(hTop[0].index) > 1))
		GetClientName(hTop[0].index, score1, PATH);
	else 
	{
		Format(score1, PATH, "---");
		hTop[0] = view_as<JailBoss>(0);
	}
	
	if (IsValidClient(hTop[1].index) && (GetClientTeam(hTop[1].index) > 1))
		GetClientName(hTop[1].index, score2, PATH);
	else 
	{
		Format(score2, PATH, "---");
		hTop[1] = view_as<JailBoss>(0);
	}
	
	if (IsValidClient(hTop[2].index) && (GetClientTeam(hTop[2].index) > 1))
		GetClientName(hTop[2].index, score3, PATH);
	else 
	{
		Format(score3, PATH, "---");
		hTop[2] = view_as<JailBoss>(0);
	}
	SetHudTextParams(-1.0, 0.4, 10.0, 255, 255, 255, 255);
	PrintCenterTextAll("");
	
	for (int i = MaxClients; i; --i) 
	{
		if (!IsClientValid(i))
			continue;
		if (!(GetClientButtons(i) & IN_SCORE)) 
		{
			player = JailBoss(i);
			ShowHudText(i, -1, "Most damage dealt by:\n1)%i - %s\n2)%i - %s\n3)%i - %s\n\nDamage Dealt: %i\nScore for this round: %i", hTop[0].iDamage, score1, hTop[1].iDamage, score2, hTop[2].iDamage, score3, player.iDamage, (player.iDamage / 600));
		}
	}
}

public void CalcScores()
{
	int j, damage, amount;
	Event scoring = CreateEvent("player_escort_score", true);
	for (int i = MaxClients; i; --i)
	{
		JailBoss player = JailBoss(i);
		if (!IsClientValid(i))
			continue;
		else if (GetClientTeam(i) < RED)
			continue;
		
		else
		{
			damage = player.iDamage;
			scoring.SetInt("player", i);
			amount = JBVSH[DamagePoints].IntValue;
			for (j = 0; damage - amount > 0; damage -= amount, j++) {  }
			scoring.SetInt("points", j);
			scoring.FireToClient(i);
			CPrintToChat(i, "{red}[JailRedux]{tan} You scored %i points.", j);
		}
	}
	delete scoring;
}

public void _NoHonorBound(const int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client)) 
	{
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		int index = GetItemIndex(weapon);
		int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		char classname[32];
		if ( IsValidEdict(active) )
			GetEdictClassname(active, classname, sizeof(classname));
		if ( index == 357 && active == weapon && !strcmp(classname, "tf_weapon_katana", false) )
		{
			SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
			if (GetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy") < 1)
				SetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
		}
	}
}

public void _StopTickle(const int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client))
		return;
	if (!GetEntProp(client, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hHighFivePartner")))
		TF2_RemoveCondition(client, TFCond_Taunting);
}

public void _ResetMediCharge(const int entid)
{
	int medigun = EntRefToEntIndex(entid);
	if (medigun > MaxClients && IsValidEntity(medigun))
		SetMediCharge(medigun, GetMediCharge(medigun) + JBVSH[MedigunReset].FloatValue);
}

public void _BossDeath(const int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client, false)) {
		JailBoss player = JailBoss(client);
		if (player.iHealth <= 0)
			player.iHealth = 0;
		
		ManageBossDeath(player);
	}
}

public Action TimerLazor(Handle timer, any medigunid)
{	// All mediguns give uber + crits (and crits to the medic)
	int medigun = EntRefToEntIndex(medigunid);
	if (medigun && IsValidEntity(medigun) && JBGameMode_GetProperty("iRoundState") == StateRunning && JBGameMode_GetProperty("iLRType") == 13)
	{
		int client = GetOwner(medigun);
		float charge = GetMediCharge(medigun);
		if (charge > 0.05) 
		{
			TF2_AddCondition(client, TFCond_CritOnWin, 0.5);
			
			int target = GetHealingTarget(client);
			if (IsClientValid(target) && IsPlayerAlive(target))
			{
				TF2_AddCondition(target, TFCond_CritOnWin, 0.5);
				JailBoss(client).iUberTarget = GetClientUserId(target);
			}
			else JailBoss(client).iUberTarget = 0;
		}
		else if (charge < 0.05) 
		{
			SetPawnTimer(_ResetMediCharge, 3.0, EntIndexToEntRef(medigun));
			return Plugin_Stop;
		}
	}
	else return Plugin_Stop;
	return Plugin_Continue;
}

public void _MusicPlay()
{
	float currtime = GetGameTime();
	if (!JBVSH[EnableMusic].BoolValue || flMusicTime > currtime)
		return;
	
	char sound[FULLPATH] = "";
	float time = -1.0;
	
	ManageMusic(sound, time);
	
	JailBoss player;
	float vol = JBVSH[MusicVolume].FloatValue;
	if (sound[0] !='\0') 
	{
		strcopy(BackgroundSong, FULLPATH, sound);
		for (int i = MaxClients; i; --i) 
		{
			if (!IsClientValid(i))
				continue;
			player = JailBoss(i);
			if (player.GetProperty("bNoMusic"))	// Wanted to get/set bNoMusic here but music could exist in core plugin if desired
				continue;
			EmitSoundToClient(i, sound, _, _, SNDLEVEL_NORMAL, SND_NOFLAGS, vol, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
		}
	}
	if (time != - 1.0) 
		flMusicTime = (currtime + time);
}

public void MakePlayerBoss(const int userid, int iBossid)
{
	JailBoss player = JailBoss(GetClientOfUserId(userid));
	player.iType = iBossid;
	player.flRAGE = 0.0;
	ManageBossTransition(player);
}

public void NoAttacking(const int wepref)
{
	int weapon = EntRefToEntIndex(wepref);
	SetNextAttack(weapon, 1.56);
}

public int FindBoss(const bool balive)
{
	for (int i=MaxClients ; i ; --i) {
		if (!IsValidClient(i) )
			continue;
		else if (balive && !IsPlayerAlive(i))
			continue;
		if (!JailBoss(i).bIsBoss)
			continue;
		return i;
	}
	return /*view_as< JailBoss >(0)*/ 0;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return Plugin_Continue;

	int vict = GetClientOfUserId(event.GetInt("victim"));
	int atkr = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsClientValid(vict) || !IsClientValid(atkr) || atkr == vict)
		return Plugin_Continue;

	JailBoss victim = JailBoss( vict, true );
	JailBoss attacker = JailBoss( atkr, true );
	int damage = event.GetInt("damageamount");
	int custom = event.GetInt("custom");
	int weapon = event.GetInt("weaponid");

	if (victim.bIsBoss)
	{
		switch (victim.iType) 
		{
			case  - 1: {  }
			default: 
			{
				victim.iHealth -= damage;
				victim.GiveRage(damage);
			}
		}
	}
		
	if (custom == TF_CUSTOM_TELEFRAG)
		damage = (IsPlayerAlive(attacker.index) ? 9001 : 1); // Telefrags normally 1-shot the boss but let's cap damage at 9k
	
	attacker.iDamage += damage;
	if (GetIndexOfWeaponSlot(attacker.index, TFWeaponSlot_Primary) == 1104)
	{
		if (weapon == TF_WEAPON_ROCKETLAUNCHER)
			attacker.iAirDamage += damage;
		int div = JBVSH[AirStrikeDamage].IntValue;
		SetEntProp(attacker.index, Prop_Send, "m_iDecapitations", attacker.iAirDamage / div);
	}
	
	int healers[MAXPLAYERS];
	int healercount = 0;
	for (int i = MaxClients; i; --i) {
		if (!IsValidClient(i))
			continue;
		else if (!IsPlayerAlive(i))
			continue;
		
		if (GetHealingTarget(i) == attacker.index) {
			healers[healercount] = i;
			healercount++;
		}
	}
	JailBoss medic;
	for (int r = 0; r < healercount; r++) 
	{  // Medics now count as 3/5 of a backstab, similar to telefrag assists.
		if (!IsValidClient(healers[r]))
			continue;
		else if (!IsPlayerAlive(healers[r]))
			continue;
		
		medic = JailBoss(healers[r]);
		if (damage < 10 || medic.iUberTarget == attacker.userid)
			medic.iDamage += damage;
		else medic.iDamage += damage / (healercount + 1);
	}
	return Plugin_Continue;
}

/********************************************************************
						COMMANDS
********************************************************************/

public Action Command_GetHPCmd(int client, int args)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return Plugin_Handled;
	
	JailBoss player = JailBoss(client);
	ManageBossCheckHealth(player);

	return Plugin_Handled;
}

/********************************************************************
						FUNCTIONS
********************************************************************/
// From VSH2... along with everything else in this sub-plugin
enum/* Bosses *//* When you add custom Bosses, add to the anonymous enum as the Boss' ID */
{
	Hale = 0, 
	Vagineer = 1, 
	CBS = 2, 
	HHHjr = 3, 
	Bunny = 4, 
};

#include "LRModVSH/bosses.sp"

#define MAXBOSS		Bunny 		// When adding new bosses, increase the MAXBOSS define for the newest boss id


public void ManageBossModels(const JailBoss base)
{
	switch (base.iType) 
	{
		case  - 1: {  }
		case Hale:ToCHale(base).SetModel();
		case Vagineer:ToCVagineer(base).SetModel();
		case CBS:ToCChristian(base).SetModel();
		case HHHjr:ToCHHHJr(base).SetModel();
		case Bunny:ToCBunny(base).SetModel();
	}
}

public void ManageMusic(char song[FULLPATH], float & time)
{	// Couldn't do this with the music foward, fired too early and would overlap with starting voicelines
	if (MapHasMusic()) { song = ""; time = -1.0; }
	else 
	{
		JailBoss currBoss = JailBoss (FindBoss(false));	// Multiboss maybe? lol
		if (currBoss) 
		{
			switch (currBoss.iType) {
				case  - 1: { song = ""; time = -1.0; }
				case Hale: {
					int rand = GetRandomInt(1, 3);
					switch (rand)
					{
						case 1:
						{
							strcopy(song, sizeof(song), HaleTheme);
							time = 170.0;
						}
						case 2:
						{
							strcopy(song, sizeof(song), HaleTheme2);
							time = 236.0;
						}
						case 3:
						{
							strcopy(song, sizeof(song), HaleTheme3);
							time = 220.0;
						}
					}
				}
				case Vagineer: {
					int rand = GetRandomInt(1, 3);
					switch (rand)
					{
						case 1:
						{
							strcopy(song, sizeof(song), VagTheme);
							time = 226.0;
						}
						case 2:
						{
							strcopy(song, sizeof(song), VagTheme2);
							time = 212.0;
						}
						case 3:
						{
							strcopy(song, sizeof(song), VagTheme3);
							time = 186.0;
						}
					}
				}
				case CBS: {
					int rand = GetRandomInt(1, 3);
					switch (rand)
					{
						case 1:
						{
							strcopy(song, sizeof(song), CBSTheme);
							time = 140.0;
						}
						case 2:
						{
							strcopy(song, sizeof(song), CBSTheme2);
							time = 146.0;
						}
						case 3:
						{
							strcopy(song, sizeof(song), CBSTheme3);
							time = 217.0;
						}
					}
				}
				case HHHjr: {
					int rand = GetRandomInt(1, 3);
					switch (rand)
					{
						case 1:
						{
							strcopy(song, sizeof(song), HHHTheme);
							time = 90.0;
						}
						case 2:
						{
							strcopy(song, sizeof(song), HHHTheme2);
							time = 150.0;
						}
						case 3:
						{
							strcopy(song, sizeof(song), HHHTheme2);
							time = 234.0;
						}
					}
				}
				case Bunny: {
					int rand = GetRandomInt(1, 3);
					switch (rand) 
					{
						case 1:
						{
							strcopy(song, sizeof(song), BunnyTheme);
							time = 272.0;
						}
						case 2:
						{
							strcopy(song, sizeof(song), BunnyTheme2);
							time = 153.0;
						}
						case 3:
						{
							strcopy(song, sizeof(song), BunnyTheme3);
							time = 185.0;
						}
					}
				}
			}
		}
	}
}

public void ManagePlayBossIntro(const JailBoss base)
{
	switch (base.iType)
	{
		case  - 1: {  }
		case Hale:ToCHale(base).PlaySpawnClip();
		case Vagineer:ToCVagineer(base).PlaySpawnClip();
		case CBS:ToCChristian(base).PlaySpawnClip();
		case HHHjr:ToCHHHJr(base).PlaySpawnClip();
		case Bunny:ToCBunny(base).PlaySpawnClip();
	}
}

public Action OnPlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iRoundState") == StateDisabled || JBGameMode_GetProperty("iLRType") != 13)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	JailBoss vict = JailBoss(victim);
	JailBoss atkr = JailBoss(attacker);

	int deathflags = event.GetInt("death_flags");
	if (vict.bIsBoss) // If victim is a boss, kill him off
		SetPawnTimer(_BossDeath, 0.1, vict.userid);
	
	if (atkr.bIsBoss && !vict.bIsBoss)
	{
		switch (atkr.iType) 
		{
			case  - 1: {  }
			case Hale:
			{
				if (deathflags & TF_DEATHFLAG_DEADRINGER)
					event.SetString("weapon", "fists");
				else ToCHale(atkr).KilledPlayer(vict, event);
			}
			case Vagineer:ToCVagineer(atkr).KilledPlayer(vict, event);
			case CBS:ToCChristian(atkr).KilledPlayer(vict, event);
			case HHHjr:ToCHHHJr(atkr).KilledPlayer(vict, event);
			case Bunny:ToCBunny(atkr).KilledPlayer(vict, event);
		}
	}

	if (!vict.bIsBoss)
		SetPawnTimer(CheckAlivePlayers, 0.2);
	
	if ( (TF2_GetPlayerClass(vict.index) == TFClass_Engineer) && !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) )
	{
		if (JBVSH[EngieBuildings].IntValue) 
		{
			switch (JBVSH[EngieBuildings].IntValue) 
			{
				case 1: 
				{
					int sentry = FindSentry(vict.index);
					if (sentry != -1) 
					{
						SetVariantInt(GetEntProp(sentry, Prop_Send, "m_iMaxHealth")+8);
						AcceptEntityInput(sentry, "RemoveHealth");
					}
				}
				case 2: 
				{
					for (int ent=MaxClients+1 ; ent<2048 ; ++ent) 
					{
						if (!IsValidEdict(ent)) 
							continue;
						else if (!HasEntProp(ent, Prop_Send, "m_hBuilder"))
							continue;
						else if (GetBuilder(ent) != vict.index)
							continue;

						SetVariantInt(GetEntProp(ent, Prop_Send, "m_iMaxHealth")+8);
						AcceptEntityInput(ent, "RemoveHealth");
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool & result)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || !IsClientValid(client))
		return Plugin_Continue;
	
	JailBoss base = JailBoss(client);
	switch (base.iType) 
	{
		case  - 1: {  }
		case HHHjr: 
		{
			if (base.iClimbs < 10) {
				base.ClimbWall(weapon, 600.0, 0.0, false);
				base.flWeighDown = 0.0;
				base.iClimbs++;
			}
		}
	}
	if (base.bIsBoss) 
	{  // Fuck random crits
		if (TF2_IsPlayerCritBuffed(base.index))
			return Plugin_Continue;
		result = false;
		return Plugin_Changed;
	}
	
	if (!base.bIsBoss) 
	{
		if (TF2_GetPlayerClass(base.index) == TFClass_Sniper && IsWeaponSlotActive(base.index, TFWeaponSlot_Melee))
			base.ClimbWall(weapon, 600.0, 15.0, true);
	}
	return Plugin_Continue;
}

public void ManageRoundEndBossInfo(bool bossWon)
{
	char victory[FULLPATH];
	gameMessage[0] = '\0';
	int i = 0;
	JailBoss base = JailBoss (FindBoss(false));
	if (!base)
		return;

	switch (base.iType) 
	{
		case Vagineer:Format(gameMessage, MAXMESSAGE, "%s\nThe Vagineer (%N) had %i (of %i) health left.", gameMessage, base.index, base.iHealth, base.iMaxHealth);
		case HHHjr:Format(gameMessage, MAXMESSAGE, "%s\nThe Horseless Headless Horsemann Jr. (%N) had %i (of %i) health left.", gameMessage, base.index, base.iHealth, base.iMaxHealth);
		case CBS:Format(gameMessage, MAXMESSAGE, "%s\nThe Christian Brutal Sniper (%N) had %i (of %i) health left.", gameMessage, base.index, base.iHealth, base.iMaxHealth);
		case Bunny:Format(gameMessage, MAXMESSAGE, "%s\nThe Easter Bunny (%N) had %i (of %i) health left.", gameMessage, base.index, base.iHealth, base.iMaxHealth);
		case Hale:Format(gameMessage, MAXMESSAGE, "%s\nSaxton Hale (%N) had %i (of %i) health left.", gameMessage, base.index, base.iHealth, base.iMaxHealth);
	}
	if (bossWon) 
	{
		victory[0] = '\0';
		switch (base.iType) 
		{
			case  - 1: {  }
			case Vagineer:Format(victory, FULLPATH, "%s%i.wav", VagineerKSpreeNew, GetRandomInt(1, 5));
			case Bunny:strcopy(victory, FULLPATH, BunnyWin[GetRandomInt(0, sizeof(BunnyWin) - 1)]);
			case Hale:Format(victory, FULLPATH, "%s%i.wav", HaleWin, GetRandomInt(1, 2));
		}
		if (victory[0] != '\0')
			EmitSoundToAll(victory);
	}

	if (gameMessage[0] !='\0') 
	{
		CPrintToChatAll("{red}[JailRedux]End of Round{tan} %s", gameMessage);
		SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
		for (i = MaxClients; i; --i) 
		{
			if (IsValidClient(i) && !(GetClientButtons(i) & IN_SCORE))
				ShowHudText(i, -1, "%s", gameMessage);
		}
	}
}


public Action HookSound(int clients[64], int & numClients, char sample[FULLPATH], int & entity, int & channel, float & volume, int & level, int & pitch, int & flags)
{
	if (!bEnabled.BoolValue || !IsValidClient(entity))
		return Plugin_Continue;
		
	if (StrContains(sample, "fall_damage", false) != -1)
		return Plugin_Handled;
		
	JailBoss base = JailBoss(entity);
	
	switch (base.iType) 
	{
		case  - 1: {  }
		case Hale: {
			if (!strncmp(sample, "vo", 2, false))
				return Plugin_Handled;
		}
		case Vagineer: {
			if (StrContains(sample, "vo/engineer_laughlong01", false)!= - 1)
			{
				strcopy(sample, FULLPATH, VagineerKSpree);
				return Plugin_Changed;
			}
			
			if (!strncmp(sample, "vo", 2, false))
			{
				if (StrContains(sample, "positivevocalization01", false)!= - 1) // For backstab sound
					return Plugin_Continue;
				if (StrContains(sample, "engineer_moveup", false)!= - 1)
					Format(sample, FULLPATH, "%s%i.wav", VagineerJump, GetRandomInt(1, 2));
				
				else if (StrContains(sample, "engineer_no", false)!= - 1 || GetRandomInt(0, 9) > 6)
					strcopy(sample, FULLPATH, "vo/engineer_no01.mp3");
				
				else strcopy(sample, FULLPATH, "vo/engineer_jeers02.mp3");
				return Plugin_Changed;
			}
			else return Plugin_Continue;
		}
		case HHHjr: {
			if (!strncmp(sample, "vo", 2, false))
			{
				if (GetRandomInt(0, 30) <= 10) {
					Format(sample, FULLPATH, "%s0%i.mp3", HHHLaught, GetRandomInt(1, 4));
					return Plugin_Changed;
				}
				if (StrContains(sample, "halloween_boss") == - 1)
					return Plugin_Handled;
			}
		}
		case Bunny: {
			if (StrContains(sample, "gibberish", false) == -1
				 && StrContains(sample, "burp", false) == -1
				 && !GetRandomInt(0, 2)) // Do sound things
			{
				strcopy(sample, PLATFORM_MAX_PATH, BunnyRandomVoice[GetRandomInt(0, sizeof(BunnyRandomVoice) - 1)]);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public void ManageBossEquipment(const JailBoss base)
{
	switch (base.iType) {
		case  - 1: {  }
		case Hale:ToCHale(base).Equip();
		case Vagineer:ToCVagineer(base).Equip();
		case CBS:ToCChristian(base).Equip();
		case HHHjr:ToCHHHJr(base).Equip();
		case Bunny:ToCBunny(base).Equip();
	}
}

public void ManageBossMedicCall(const JailBoss base)
{
	switch (base.iType) {
		case  - 1: {  }
		case Hale, Vagineer, CBS, HHHjr, Bunny:
		{
			if (base.flRAGE < 100.0)
				return;
			DoTaunt(base.index, "", 0);
		}
	}
}

public void ManageBossTaunt(const JailBoss base)
{
	switch (base.iType) {
		case  - 1: {  }
		case Hale:ToCHale(base).RageAbility();
		case Vagineer:ToCVagineer(base).RageAbility();
		case CBS:ToCChristian(base).RageAbility();
		case HHHjr:ToCHHHJr(base).RageAbility();
		case Bunny:ToCBunny(base).RageAbility();
	}
}

public void ManagePlayerJarated(const JailBoss attacker, const JailBoss victim)
{
	switch (victim.iType) 
	{
		case  - 1: {  }
		case Hale, Vagineer, CBS, HHHjr, Bunny:
		victim.flRAGE -= JBVSH[JarateRage].FloatValue;
	}
}

public void ManageBossDeath(const JailBoss base)
{
	switch (base.iType) 
	{
		case  - 1: {  }
		case Hale:ToCHale(base).Death();
		case Vagineer:ToCVagineer(base).Death();
		case CBS:ToCChristian(base).Death();
		case HHHjr:ToCHHHJr(base).Death();
		case Bunny:ToCBunny(base).Death();
	}
}

public void ManageEntityCreated(const int entity, const char[] classname)
{
	if (JBGameMode_GetProperty("iRoundState") == StateRunning && !strcmp(classname, "tf_projectile_pipe", false))
		SDKHook(entity, SDKHook_SpawnPost, OnEggBombSpawned);
}

public void OnEggBombSpawned(int entity)
{
	int owner = GetOwner(entity);
	JailBoss boss = JailBoss(owner);
	if (IsClientValid(owner) && boss.bIsBoss && boss.iType == Bunny)
		CreateTimer(0.0, Timer_SetEggBomb, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public void ManageBossTransition(const JailBoss base)/* whatever stuff needs initializing should be done here */
{
	switch (base.iType) {
		case  - 1: {  }
		case Hale:
		TF2_SetPlayerClass(base.index, TFClass_Soldier, _, false);
		case Vagineer:
		TF2_SetPlayerClass(base.index, TFClass_Engineer, _, false);
		case CBS:
		TF2_SetPlayerClass(base.index, TFClass_Sniper, _, false);
		case HHHjr, Bunny:
		TF2_SetPlayerClass(base.index, TFClass_DemoMan, _, false);
	}
	ManageBossModels(base);
	switch (base.iType) {
		case  - 1: {  }
		case HHHjr:ToCHHHJr(base).flCharge = -1000.0;
	}
	ManageBossEquipment(base);
}

public void PrepPlayers(const JailBoss player)
{
	int client = player.index;
	if (!IsValidClient(client))
		return;
	if (!IsPlayerAlive(client)
		|| JBGameMode_GetProperty("iRoundState") == StateEnding
		|| player.bIsBoss)
	return;
	
	TF2Attrib_RemoveAll(client);
	if (GetClientTeam(client)!= RED && GetClientTeam(client) > int(TFTeam_Spectator))
	{
		player.ForceTeamChange(RED);
		TF2_RegeneratePlayer(client); // Added fix by Chdata to correct team colors
	}
	TF2_RegeneratePlayer(client);
	SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	
	if (IsValidEntity(FindPlayerBack(client, { 444 }, 1))) //  Fixes mantreads to have jump height again
	{
		TF2Attrib_SetByDefIndex(client, 58, 1.3); //  "Self dmg push force increased"
	}
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	int index = -1;
	if (weapon > MaxClients && IsValidEdict(weapon))
	{
		index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch (index) {
			case 237:
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				weapon = player.SpawnWeapon("tf_weapon_rocketlauncher", 18, 1, 0, "114 ; 1.0");
				SetWeaponAmmo(weapon, 20);
			}
			case 17, 204:
			{
				if (GetItemQuality(weapon) != 10) {
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
					player.SpawnWeapon("tf_weapon_syringegun_medic", 17, 1, 10, "17 ; 0.05 ; 144 ; 1");
				}
			}
			case 224: //letranger beta weapon
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				weapon = player.SpawnWeapon("tf_weapon_revolver", 224, 1, 10, "413 ; 1 ; 3 ; 0.5 ; 6 ; 0.75 ; 2 ; 1.15");
			}
		}
	}
	weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (weapon > MaxClients && IsValidEdict(weapon))
	{
		index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch (index) {
			/*case 57:	// Razorback
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_smg", 16, 1, 0, "");
			}*/
			case 265: // Stickyjumper
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_pipebomblauncher", 20, 1, 0, "");
				SetWeaponAmmo(weapon, 24);
			}
			/*case 311, 433:
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_pipebomblauncher", 20, 5, 10, "280 ; 3 ; 6 ; 0.7 ; 97 ; 0.5 ; 78 ; 1.2");
				SetWeaponAmmo(weapon, GetMaxAmmo(client, 1));
			}*/
			case 528: //Short Circuit
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_laser_pointer", 140, 1, 0, "");
			}
			case 735, 736, 810, 831, 933, 1080, 1102: // Replace sapper with more useful nail-firing Pistol
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_handgun_scout_secondary", 23, 5, 10, "280 ; 5 ; 6 ; 0.7 ; 2 ; 0.66 ; 4 ; 4.167 ; 78 ; 8.333 ; 137 ; 6.0");
				SetWeaponAmmo(weapon, 200);
			}
			/*case 46, 1145: //bonk atomic punch
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_lunchbox_drink", 163, 1, 0, "144 ; 2");
			}*/
			case 39, 351, 1081:
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_flaregun", index, 5, 10, "551 ; 1 ; 25 ; 0.5 ; 207 ; 1.66 ; 144 ; 1 ; 58 ; 3.0");
				SetWeaponAmmo(weapon, 16);
			}
			case 740:
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				weapon = player.SpawnWeapon("tf_weapon_flaregun", index, 5, 10, "551 ; 1 ; 25 ; 0.5 ; 207 ; 1.33 ; 416 ; 3 ; 58 ; 2.08 ; 1 ; 0.65");
				SetWeaponAmmo(weapon, 16);
			}
		}
	}
	/*if ( IsValidEntity (FindPlayerBack(client, { 57 }, 1)) )
	{
		RemovePlayerBack(client, { 57 }, 1);
		weapon = player.SpawnWeapon("tf_weapon_smg", 16, 1, 0, "");
	}*/
	if (IsValidEntity(FindPlayerBack(client, { 642 }, 1)))
	{
		player.SpawnWeapon("tf_weapon_smg", 16, 1, 6, "149 ; 1.5 ; 1 ; 0.85");
	}
	if (IsValidEntity(FindPlayerBack(client, { 231 }, 1)))
	{
		player.SpawnWeapon("tf_weapon_smg", 16, 1, 6, "16 ; 1.0 ; 1 ; 0.85");
	}
	weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	if (weapon > MaxClients && IsValidEdict(weapon)) 
	{
		index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch (index)
		{
			/*case 331: {
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
				weapon = player.SpawnWeapon("tf_weapon_fists", 195, 1, 6, "");
			}*/
			case 357:SetPawnTimer(_NoHonorBound, 1.0, player.userid);
			case 171:
			{  // Remove and replace shiv to avoid idiots hitting themselves while climbing walls
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
				weapon = player.SpawnWeapon("tf_weapon_club", 3, 1, 0, "");
			}
		}
	}
	weapon = GetPlayerWeaponSlot(client, 4);
	if (weapon > MaxClients && IsValidEdict(weapon) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 60)
	{
		TF2_RemoveWeaponSlot(client, 4);
		weapon = player.SpawnWeapon("tf_weapon_invis", 30, 1, 0, "2 ; 1.0");
	}
	TFClassType equip = TF2_GetPlayerClass(client);
	switch (equip) 
	{
		case TFClass_Medic:
		{
			weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			int mediquality = GetItemQuality(weapon);
			if (mediquality != 10) {
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				if (JBVSH[PermOverheal].BoolValue)
					weapon = player.SpawnWeapon("tf_weapon_medigun", 35, 5, 10, "14 ; 0.0 ; 18 ; 0.0 ; 10 ; 1.25 ; 178 ; 0.75");
				else weapon = player.SpawnWeapon("tf_weapon_medigun", 35, 5, 10, "18 ; 0.0 ; 10 ; 1.25 ; 178 ; 0.75");
				//200 ; 1 for area of effect healing, 178 ; 0.75 Faster switch-to, 14 ; 0.0 perm overheal, 11 ; 1.25 Higher overheal
				if (GetMediCharge(weapon) < 0.41)
					SetMediCharge(weapon, 0.41);
			}
		}
	}
}

public Action ManageOnBossTakeDamage(const JailBoss victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	switch (victim.iType) 
	{
		case  - 1: {  }
		case Hale, Vagineer, CBS, HHHjr, Bunny: 
		{
			char trigger[32];
			if (GetEdictClassname(attacker, trigger, sizeof(trigger)) && !strcmp(trigger, "trigger_hurt", false))
			{
				if (damage >= 100.0)
				{
					if (JBGameMode_GetProperty("bWardayTeleportSetBlue"))
						victim.TeleportToPosition(WBLU);
					else TeleportToSpawn(victim.index, BLU);
				}
			}
			if (attacker <= 0 || attacker > MaxClients)
				return Plugin_Continue;
			
			char classname[64], strEntname[32];
			if (IsValidEdict(inflictor))
				GetEntityClassname(inflictor, strEntname, sizeof(strEntname));
			if (IsValidEdict(weapon))
				GetEdictClassname(weapon, classname, sizeof(classname));
	
			int weap = GetPlayerWeaponSlot(victim.index, TFWeaponSlot_Melee);
			int index = GetItemIndex(weap);
			int active = GetEntPropEnt(victim.index, Prop_Send, "m_hActiveWeapon");
			
			int wepindex = GetItemIndex(weapon);
			if (damagecustom == TF_CUSTOM_BACKSTAB || (!strcmp(classname, "tf_weapon_knife", false) && damage > victim.iHealth))
				// Bosses shouldn't die from a single backstab
			{
				switch (victim.iType) 
				{
					case Hale:Format(snd, FULLPATH, "%s%i.wav", HaleStubbed132, GetRandomInt(1, 4));
					case Vagineer:strcopy(snd, FULLPATH, "vo/engineer_positivevocalization01.mp3");
					case HHHjr:Format(snd, FULLPATH, "vo/halloween_boss/knight_pain0%d.mp3", GetRandomInt(1, 3));
					case Bunny:strcopy(snd, PLATFORM_MAX_PATH, BunnyPain[GetRandomInt(0, sizeof(BunnyPain) - 1)]);
				}
				EmitSoundToAll(snd, victim.index); EmitSoundToAll(snd, victim.index);
				
				float changedamage = ((Pow(float(victim.iMaxHealth) * 0.0014, 2.0) + 899.0) - (float(victim.iMaxHealth) * (float(victim.iStabbed) / 100)));
				if (victim.iStabbed < 4)
					victim.iStabbed++;
				damage = changedamage / 3; // You can level "damage dealt" with backstabs
				damagetype |= DMG_CRIT;
				
				EmitSoundToAll("player/spy_shield_break.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
				EmitSoundToAll("player/crit_received3.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
				float curtime = GetGameTime();
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", curtime + 2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", curtime + 2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", curtime + 1.0);
				TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 1.5);
				TF2_AddCondition(attacker, TFCond_Ubercharged, 2.0);
				int vm = GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
				if (vm > MaxClients && IsValidEntity(vm) && TF2_GetPlayerClass(attacker) == TFClass_Spy)
				{
					int melee = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
					int anim = 15;
					switch (melee) 
					{
						case 727:anim = 41;
						case 4, 194, 665, 794, 803, 883, 892, 901, 910:anim = 10;
						case 638:anim = 31;
					}
					SetEntProp(vm, Prop_Send, "m_nSequence", anim);
				}
				PrintCenterText(attacker, "You Tickled The Boss!");
				PrintCenterText(victim.index, "You Were Just Backstabbed!");
				int pistol = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary);
				if (pistol == 525) 
				{  //Diamondback gives 4 crits on backstab
					int iCrits = GetEntProp(attacker, Prop_Send, "m_iRevengeCrits");
					SetEntProp(attacker, Prop_Send, "m_iRevengeCrits", iCrits + 4);
				}
				if (wepindex == 356) 
				{
					int health = GetClientHealth(attacker) + 180;
					if (health > 195)
						health = 300;
					SetEntProp(attacker, Prop_Data, "m_iHealth", health);
					SetEntProp(attacker, Prop_Send, "m_iHealth", health);
				}
				if (wepindex == 461) //Big Earner gives full cloak on backstab
					SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);
				
				return Plugin_Changed;
			}
			if (damagecustom == TF_CUSTOM_TELEFRAG) 
			{
				damage = victim.iHealth + 0.2;
				return Plugin_Changed;
			}
			if (damagecustom == TF_CUSTOM_TAUNT_BARBARIAN_SWING) // Gives 4 heads if successful sword killtaunt!
			{
				repeat(4)IncrementHeadCount(attacker);
			}
			if (damagecustom == TF_CUSTOM_BOOTS_STOMP && IsValidEntity(FindPlayerBack(attacker, { 405, 444, 608 }, 3)))
			{
				damage = 1024.0;
				return Plugin_Changed;
			}
			if (!strcmp(classname, "tf_weapon_shotgun_hwg", false) 
				|| !strcmp(classname, "tf_weapon_shotgun_soldier", false) 
				&& wepindex != 415)
			{
				int health = GetClientHealth(attacker);
				int newHealth;
				int maxhp = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
				if (health < RoundFloat(maxhp * 1.5)) 
				{
					newHealth = RoundFloat(damage + health);
					if (damage + health > RoundFloat(maxhp * 1.5))
						newHealth = RoundFloat(maxhp * 1.5);
					SetEntityHealth(attacker, newHealth);
				}
			}
			if (!strcmp(classname, "tf_weapon_handgun_scout_secondary", false) && wepindex == 773)
			{
				int health = GetClientHealth(attacker);
				int newHealth;
				int maxhp = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
				if (health >= maxhp && health < RoundFloat(maxhp * 1.5) && (health >= maxhp)) 
				{
					newHealth = RoundFloat(damage / 3 + health);
					if (damage / 3 + health > RoundFloat(maxhp * 1.5))
						newHealth = RoundFloat(maxhp * 1.5);
					SetEntityHealth(attacker, newHealth);
				}
			}
			if (JBVSH[Anchoring].BoolValue) 
			{
				int iFlags = GetEntityFlags(victim.index);
				// If Hale is ducking on the ground, it's harder to knock him back
				if ((iFlags & (FL_ONGROUND | FL_DUCKING)) == (FL_ONGROUND | FL_DUCKING))
					TF2Attrib_SetByDefIndex(victim.index, 252, 0.0);						
				else TF2Attrib_RemoveByDefIndex(victim.index, 252);
			}
	
			switch (wepindex) 
			{
				case 593: //Third Degree
				{
					int healers[MAXPLAYERS];
					int healercount = 0;
					for (int i = MaxClients; i; --i) 
					{
						if (IsClientValid(i) && IsPlayerAlive(i) && GetHealingTarget(i) == attacker)
						{
							healers[healercount] = i;
							healercount++;
						}
					}
					for (int i = 0; i < healercount; i++) 
					{
						if (IsValidClient(healers[i]) && IsPlayerAlive(healers[i]))
						{
							int medigun = GetPlayerWeaponSlot(healers[i], TFWeaponSlot_Secondary);
							if (IsValidEntity(medigun)) 
							{
								char cls[32];
								GetEdictClassname(medigun, cls, sizeof(cls));
								if (!strcmp(cls, "tf_weapon_medigun", false)) 
								{
									float uber = GetMediCharge(medigun) + (0.1 / healercount);
									float max = 1.0;
									if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease"))
										max = 1.5;
									if (uber > max)
										uber = max;
									SetMediCharge(medigun, uber);
								}
							}
						}
					}
				}
				case 14, 201, 230, 402, 526, 664, 752, 792, 801, 851, 881, 890, 899, 908, 957, 966, 1098, 15000, 15007, 15019, 15023, 15033, 15059, 15070, 15071, 15072, 15111, 15112, 15135, 15136, 15154, 30665:
				{
					switch (wepindex) //cleaner to read than if wepindex == || wepindex == || etc
					{
						case 14, 201, 664, 792, 801, 851, 881, 890, 899, 908, 957, 966, 1098, 15000, 15007, 15019, 15023, 15033, 15059, 15070, 15071, 15072, 15111, 15112, 15135, 15136, 15154:
						{
							if (JBGameMode_GetProperty("iRoundState") != StateEnding)
							{
								float bossGlow = victim.flGlowtime;
								float chargelevel = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
								float time = (bossGlow > 10 ? 1.0 : 2.0);
								time += (bossGlow > 10 ? (bossGlow > 20 ? 1 : 2) : 4) * (chargelevel / 100);
								bossGlow += RoundToCeil(time);
								if (bossGlow > 30.0)
									bossGlow = 30.0;
								victim.flGlowtime = bossGlow;
							}
						}
					}
					if (wepindex == 402) 
					{
						if (damagecustom == TF_CUSTOM_HEADSHOT)
							IncrementHeadCount(attacker, false);
					}
					if (wepindex == 752 && JBGameMode_GetProperty("iRoundState") != StateEnding)
					{
						float chargelevel = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
						float add = 10 + (chargelevel / 10);
						if (TF2_IsPlayerInCondition(attacker, view_as<TFCond>(46)))
							add /= 3;
						float rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
						SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", (rage + add > 100) ? 100.0 : rage + add);
					}
					if (!(damagetype & DMG_CRIT)) 
					{
						bool ministatus = (TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed) || TF2_IsPlayerInCondition(attacker, TFCond_CritHype));
						
						damage *= (ministatus) ? 2.222222 : 3.0;
						if (wepindex == 230) 
							victim.flRAGE -= (damage * 0.0);
						return Plugin_Changed;
					}
					else if (wepindex == 230)
						victim.flRAGE -= (damage * 0.0);
				}
				case 132, 266, 482, 1082:IncrementHeadCount(attacker);
				case 355:victim.flRAGE -= JBVSH[FanoWarRage].FloatValue;
				case 317, 327:SpawnSmallHealthPackAt(attacker, GetClientTeam(attacker));
				case 416: // Chdata's Market Gardener backstab
				{
					if (JBPlayer(attacker).GetProperty("bInJump"))
					{
						damage = (Pow(float(victim.iMaxHealth), (0.74074))/*512.0*/-(victim.iMarketted / 128 * float(victim.iMaxHealth))) / 3.0;
						//divide by 3 because this is basedamage and lolcrits (0.714286)) + 1024.0)
						damagetype |= DMG_CRIT;
						
						if (victim.iMarketted < 5)
							victim.iMarketted++;
						
						PrintCenterText(attacker, "You Market Gardened the Boss!");
						PrintCenterText(victim.index, "You Were Just Market Gardened!");
						
						EmitSoundToAll("player/doubledonk.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
						SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
						
						if (TF2_IsPlayerInCondition(attacker, TFCond_Parachute))
						{
							damage *= 0.67;
							RemoveParachute(attacker);
						}
						return Plugin_Changed;
					}
				}
				case 609: // Sticky Gardening
				{
					if (JBPlayer(attacker).GetProperty("bInJump"))
					{
						damage = (Pow(float(victim.iMaxHealth), (0.74074))/*512.0*/-(victim.iMarketted / 128 * float(victim.iMaxHealth))) / 2.5;
						
						damagetype |= DMG_CRIT;
						
						if (victim.iMarketted < 5)
							victim.iMarketted++;
						
						PrintCenterText(attacker, "You Sticky Gardened the Boss!");
						PrintCenterText(victim.index, "You Were Just Sticky Gardened!");
						
						EmitSoundToAll("player/doubledonk.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
						SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
						
						if (TF2_IsPlayerInCondition(attacker, TFCond_Parachute))
						{
							damage *= 0.67;
							RemoveParachute(attacker);
						}
						
						return Plugin_Changed;
					}
				}
				case 154, 214, 310:
				{
					int health = GetClientHealth(attacker);
					int max = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
					int newhealth = health + 25;
					if (health < max + 50) 
					{
						if (newhealth > max + 50)
							newhealth = max + 50;
						SetEntProp(attacker, Prop_Data, "m_iHealth", newhealth);
						SetEntProp(attacker, Prop_Send, "m_iHealth", newhealth);
					}
					if (TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						TF2_RemoveCondition(attacker, TFCond_OnFire);
				}
				case 357:
				{
					SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
					if (GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy") < 1)
						SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
					int health = GetClientHealth(attacker);
					int max = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
					int newhealth = health + 35;
					if (TF2_GetPlayerClass(attacker) == TFClass_Soldier) 
					{
						if (health < max + 25) 
						{
							if (newhealth > max + 25)
							{ newhealth = max + 25; }
							SetEntProp(attacker, Prop_Data, "m_iHealth", newhealth);
							SetEntProp(attacker, Prop_Send, "m_iHealth", newhealth);
						}
					}
					else if (TF2_GetPlayerClass(attacker) == TFClass_DemoMan) 
					{	// Because Demoman obviously needs more methods of damage in VSH
						if (health < max + 100) 
						{
							if (newhealth > max + 100)
							{ newhealth = max + 100; }
							SetEntProp(attacker, Prop_Data, "m_iHealth", newhealth);
							SetEntProp(attacker, Prop_Send, "m_iHealth", newhealth);
						}
					}
					if (TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						TF2_RemoveCondition(attacker, TFCond_OnFire);
					if (index == 357 && active == weap) 
					{
						damage = 195.0;
						return Plugin_Changed;
					}
				}
				case 61, 1006: // Ambassador does 2.5x damage on headshot
				{
					if (damagecustom == TF_CUSTOM_HEADSHOT)
					{
						damage *= 2.5; 
						return Plugin_Changed;
					}
				}
				case 751: // Cleaner's Carbine does 2.5x damage on headshot
				{
					if (damagecustom == TF_CUSTOM_HEADSHOT)
					{
						damage = 27.0;
						damagetype |= DMG_CRIT;
						return Plugin_Changed;
					}
				}
				case 525, 595:
				{
					int iCrits = GetEntProp(attacker, Prop_Send, "m_iRevengeCrits");
					if (iCrits) 
					{  // If a revenge crit was used, give a damage bonus
						damage = 85.0;
						return Plugin_Changed;
					}
				}
				case 656:
				{	// Holiday Punch
					SetPawnTimer(_StopTickle, JBVSH[StopTickleTime].FloatValue, victim.userid);
					if (TF2_IsPlayerInCondition(attacker, TFCond_Dazed))
						TF2_RemoveCondition(attacker, TFCond_Dazed);
				}
				case 307:
				{	// Caber is a meme
					if (TF2_IsPlayerInCondition(attacker, TFCond_Ubercharged))
						ForcePlayerSuicide(attacker);
				}
				case 43:TF2_AddCondition(attacker, TFCond_CritOnWin, 4.0);	// KGB
			}
		}
	}
	return Plugin_Continue;
}

public Action ManageOnBossDealDamage(const JailBoss victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	JailBoss fighter = JailBoss(attacker);
	switch (fighter.iType) 
	{
		case  - 1: {  }
		case Hale, Vagineer, CBS, HHHjr, Bunny: 
		{
			if (damagetype & DMG_CRIT)
				damagetype &= ~DMG_CRIT;
			
			int client = victim.index;
			
			if (damagecustom == TF_CUSTOM_BOOTS_STOMP)
			{	// Hale stomps should do a fair bit of damage, but shouldn't always insta-kill classes
				float flFallVelocity = GetEntPropFloat(inflictor, Prop_Send, "m_flFallVelocity");
				damage = 10.0 * (GetRandomFloat(0.8, 1.2) * (5.0 * (flFallVelocity / 300.0)));
				return Plugin_Changed;
			}
			
			if (TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed))
			{	// Buff Banner
				ScaleVector(damageForce, 9.0);
				damage *= 0.3;
				return Plugin_Changed;
			}
			if (TF2_IsPlayerInCondition(client, TFCond_CritMmmph))
			{	// Phlog obv
				damage *= 0.25;
				return Plugin_Changed;
			}
			
			int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			char mediclassname[32];
			if (IsValidEdict(medigun)
				 && GetEdictClassname(medigun, mediclassname, sizeof(mediclassname))
				 && !strcmp(mediclassname, "tf_weapon_medigun", false)
				 && !TF2_IsPlayerInCondition(client, TFCond_Ubercharged)
				 && weapon == GetPlayerWeaponSlot(attacker, 2)) 
			{

				if (GetMediCharge(medigun) >= 0.90) 
				{
					SetMediCharge(medigun, 0.5);
					damage *= 10;
					TF2_AddCondition(client, TFCond_UberchargedOnTakeDamage, 0.1);	// TFCond_Bonked gives that shitty LostFooting thing when you get hit, have to use this
					return Plugin_Changed;
				}
			}
			if (TF2_GetPlayerClass(client) == TFClass_Spy) // Eggs probably do melee damage to spies, then? That's not ideal, but eh.
			{
				if (GetEntProp(client, Prop_Send, "m_bFeignDeathReady") && !TF2_IsPlayerInCondition(client, TFCond_Cloaked))
				{
					if (damagetype & DMG_CRIT)
						damagetype &= ~DMG_CRIT;
					damage = 85.0;
					return Plugin_Changed;
				}
				if (TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_DeadRingered))
				{
					if (damagetype & DMG_CRIT)
						damagetype &= ~DMG_CRIT;
					damage = 60.0;
					return Plugin_Changed;
				}
			}
			int ent = -1;
			while ((ent = FindEntityByClassname(ent, "tf_wearable_demoshield")) != -1)
			{
				if (GetOwner(ent) == client
					&& damage >= float(GetClientHealth(client))
					&& !TF2_IsPlayerInCondition(client, TFCond_Ubercharged)
					&& !GetEntProp(ent, Prop_Send, "m_bDisguiseWearable")
					&& weapon == GetPlayerWeaponSlot(attacker, 2))
				{
					TF2_AddCondition(client, TFCond_UberchargedOnTakeDamage, 0.1);
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 1.0);
					TF2_RemoveWearable(client, ent);
					EmitSoundToAll("player/spy_shield_break.wav", client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
					break;
				}
			}
			if (IsValidEntity(FindPlayerBack(client, { 57 }, 1))	// Razorback operates as a shield
				&& !TF2_IsPlayerInCondition(client, TFCond_Ubercharged)
				&& weapon == GetPlayerWeaponSlot(attacker, 2))
			{
				TF2_AddCondition(client, TFCond_UberchargedOnTakeDamage, 0.1);
				TF2_AddCondition(client, TFCond_SpeedBuffAlly, 1.0);
				RemovePlayerBack(client, { 57 }, 1);
				EmitSoundToAll("player/spy_shield_break.wav", client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
			}
		}
	}
	return Plugin_Continue;
}

public void CheckAlivePlayers()
{
	if (JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;
	
	int living = GetLivingPlayers(RED);
	if (!living)
		ForceTeamWin(BLU);
	
	if (living == 1 && JBGameMode_GetProperty("iTimeLeft") >= 0)
	{
		JailBoss player = JailBoss (FindBoss(false));
		if (player.bIsBoss)
		{
			switch (player.iType)
			{
				case  - 1: {  }
				case Hale:ToCHale(player).LastPlayerSoundClip();
				case Vagineer:ToCVagineer(player).LastPlayerSoundClip();
				case CBS:ToCChristian(player).LastPlayerSoundClip();
				case Bunny:ToCBunny(player).LastPlayerSoundClip();
			}
		}
	}
}

public void ManageUberDeploy(const JailBoss medic, const JailBoss patient)
{
	int medigun = GetPlayerWeaponSlot(medic.index, TFWeaponSlot_Secondary);
	if (IsValidEntity(medigun)) 
	{
		char strMedigun[32]; GetEdictClassname(medigun, strMedigun, sizeof(strMedigun));
		if (!strcmp(strMedigun, "tf_weapon_medigun", false))
		{
			SetMediCharge(medigun, 1.51);
			TF2_AddCondition(medic.index, TFCond_CritOnWin, 0.5, medic.index);
			if (IsValidClient(patient.index) && IsPlayerAlive(patient.index))
			{
				TF2_AddCondition(patient.index, TFCond_CritOnWin, 0.5, medic.index);
				medic.iUberTarget = patient.userid;
			}
			else medic.iUberTarget = 0;
			CreateTimer(0.1, TimerLazor, EntIndexToEntRef(medigun), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void StopBackGroundMusic()
{
	for (int i = MaxClients; i; --i) 
	{
		if (!IsClientValid(i))
			continue;

		StopSound(i, SNDCHAN_AUTO, BackgroundSong);
	}
}

public void ManageBossCheckHealth(const JailBoss base)
{
	static int LastBossTotalHealth;
	float currtime = GetGameTime();
	if (base.bIsBoss) 
	{  // If a boss reveals their own health, only show that one boss' health.
		switch (base.iType) 
		{
			case  - 1: {  }
			case Hale:PrintCenterTextAll("Saxton Hale showed his current HP: %i of %i", base.iHealth, base.iMaxHealth);
			case Vagineer:PrintCenterTextAll("The Vagineer showed his current HP: %i of %i", base.iHealth, base.iMaxHealth);
			case CBS:PrintCenterTextAll("The Christian Brutal Sniper showed his current HP: %i of %i", base.iHealth, base.iMaxHealth);
			case HHHjr:PrintCenterTextAll("The Horseless Headless Horsemann Jr. showed his current HP: %i of %i", base.iHealth, base.iMaxHealth);
			case Bunny:PrintCenterTextAll("The Easter Bunny showed his current HP: %i of %i", base.iHealth, base.iMaxHealth);

		}
		LastBossTotalHealth = base.iHealth;
		return;
	}
	if (currtime >= flHealthTime) 
	{  // If a non-boss is checking health, reveal all Boss' hp
		iHealthChecks++;
		JailBoss boss;
		int totalHealth;
		gameMessage[0] = '\0';
		for (int i = MaxClients; i; --i) 
		{
			if (!IsValidClient(i) || !IsPlayerAlive(i)) // Exclude dead bosses for health check
				continue;
			boss = JailBoss(i);
			if (!boss.bIsBoss)
				continue;
			
			switch (boss.iType) 
			{
				case Vagineer:Format(gameMessage, MAXMESSAGE, "%s\nThe Vagineer's current health is: %i of %i", gameMessage, boss.iHealth, boss.iMaxHealth);
				case HHHjr:Format(gameMessage, MAXMESSAGE, "%s\nThe Horseless Headless Horsemann Jr's current health is: %i of %i", gameMessage, boss.iHealth, boss.iMaxHealth);
				case CBS:Format(gameMessage, MAXMESSAGE, "%s\nThe Christian Brutal Sniper's current health is: %i of %i", gameMessage, boss.iHealth, boss.iMaxHealth);
				case Hale:Format(gameMessage, MAXMESSAGE, "%s\nSaxton Hale's current health is: %i of %i", gameMessage, boss.iHealth, boss.iMaxHealth);
				case Bunny:Format(gameMessage, MAXMESSAGE, "%s\nThe Easter Bunny's current health is: %i of %i", gameMessage, boss.iHealth, boss.iMaxHealth);
			}
			totalHealth += boss.iHealth;
		}
		PrintCenterTextAll(gameMessage);
		CPrintToChatAll("{red}[JailRedux] Boss Health Check{tan} %s", gameMessage);
		LastBossTotalHealth = totalHealth;
		flHealthTime = (iHealthChecks < 3 ? 10.0 : 60.0);
	}
	else CPrintToChat(base.index, "{red}[JailRedux]{tan} You can see the Boss HP now (wait %i seconds). Last known total health was %i.", RoundFloat(flHealthTime - currtime), LastBossTotalHealth);
}

public void ManageMessageIntro()
{
	JailBoss base = JailBoss (FindBoss(false));

	gameMessage[0] = '\0';
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_door"))!= - 1)
	{	// Redundant but a backup in case doors don't work for some reason (which should never happen)
		AcceptEntityInput(ent, "Open");
		AcceptEntityInput(ent, "Unlock");
	}
	if (!base)
		return;
	int i;
	switch (base.iType) 
	{
		case  - 1: {  }
		case Hale:Format(gameMessage, MAXMESSAGE, "%s\n%N has become Saxton Hale with %i Health", gameMessage, base.index, base.iHealth);
		case Vagineer:Format(gameMessage, MAXMESSAGE, "%s\n%N has become the Vagineer with %i Health", gameMessage, base.index, base.iHealth);
		case CBS:Format(gameMessage, MAXMESSAGE, "%s\n%N has become the Christian Brutal Sniper with %i Health", gameMessage, base.index, base.iHealth);
		case HHHjr:Format(gameMessage, MAXMESSAGE, "%s\n%N has become The Horseless Headless Horsemann Jr. with %i Health", gameMessage, base.index, base.iHealth);
		case Bunny:Format(gameMessage, MAXMESSAGE, "%s\n%N has become The Easter Bunny with %i Health", gameMessage, base.index, base.iHealth);
	}
	SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
	for (i = MaxClients; i; --i) {
		if (IsValidClient(i))
			ShowHudText(i, -1, "%s", gameMessage);
	}
	SetPawnTimer(_MusicPlay, 4.0);
}

/********************************************************************
						[F*O*R*W*A*R*D*S]
********************************************************************/
// Obviously, here we place what would normally go under the proper, called function in the core plugin
public void fwdOnLRRoundActivate(const JBPlayer player)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;
	JailBoss base = JailBoss(player.index);
	if (GetClientTeam(base.index) != RED && GetClientTeam(base.index) > view_as<int>(TFTeam_Spectator) && !base.bIsBoss)
		base.ForceTeamChange(RED);

	base.iDamage = 0;
	SetPawnTimer( PrepPlayers, 0.2, base.userid );
}
public void fwdOnManageRoundStart()
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;
	JBGameMode_SetProperty("bWardenLocked", true);
	JBGameMode_SetProperty("bCellsOpened", true);
	JailBoss rand = JailBoss(Client_GetRandom(CLIENTFILTER_ALIVE | CLIENTFILTER_NOBOTS));
	int BOSS = GetRandomInt(Hale, MAXBOSS);
	//MakePlayerBoss(rand.userid, BOSS);
	rand.ConvertToBoss(BOSS);
	if (GetClientTeam(rand.index) == RED)
		rand.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand.index))
		TF2_RespawnPlayer(rand.index);
	if (JBGameMode_GetProperty("bWardayTeleportSetBlue"))
		rand.TeleportToPosition(WBLU);
	else ServerCommand("sm_freeze #%i 10", rand.userid);
	rand.iMaxHealth = CalcBossHealth(760.8, JBGameMode_GetProperty("iPlaying"), 1.0, 1.0341, 2046.0);
	int maxhp = GetEntProp(rand.index, Prop_Data, "m_iMaxHealth");
	TF2Attrib_RemoveAll(rand.index);
	TF2Attrib_SetByDefIndex( rand.index, 26, float(rand.iMaxHealth)-maxhp );
	TF2Attrib_SetByDefIndex( rand.index, 275, 1.0 );
	if (GetClientTeam(rand.index) != BLU)
		rand.ForceTeamChange(BLU);
	rand.iHealth = rand.iMaxHealth;
	SetEntityHealth(rand.index, rand.iHealth);
	JBGameMode_SetProperty("bDisableCriticals", true);

	for (int i=MaxClients ; i ; --i) 
	{
		if (!IsValidClient(i) || GetClientTeam(i) <= view_as<int>(TFTeam_Spectator))
			continue;

		JailBoss player = JailBoss(i);
		if (player.bIsBoss)
			continue;

		SetEntityMoveType(i, MOVETYPE_WALK);
		if (GetClientTeam(i) != RED)
			player.ForceTeamChange(RED);
		SetPawnTimer( PrepPlayers, 0.2, player.userid );

		if (GetClientTeam(i) == BLU)
			player.ForceTeamChange(RED);
	}
	SetPawnTimer(ManagePlayBossIntro, 0.2, rand);
	SetPawnTimer(CheckAlivePlayers, 0.4);
	ManageMessageIntro();
}
public void fwdOnLRRoundEnd(const JBPlayer player)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;
	JailBoss(player.index).Init_VSH();
	TF2Attrib_RemoveByDefIndex(player.index, 26);
}
public void fwdOnManageRoundEnd(Event event)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;

	//JBGameMode_ManageCells(OPEN);
	JBGameMode_SetProperty("bDisableCriticals", false);
	flMusicTime = 0.0;
	JBGameMode_SetProperty("bWardenLocked", true);
	StopBackGroundMusic();
	ShowPlayerScores();
	SetPawnTimer(CalcScores, 3.0);

	ManageRoundEndBossInfo( (event.GetInt("team") == BLU) );
}
/*public void fwdOnWardenGet(const JBPlayer player)
{

}
public void fwdOnClientTouch(const JBPlayer toucher, const JBPlayer touchee)
{

}*/
public void fwdOnRedThink(const JBPlayer player)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 19 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;
	if (GetClientTeam(player.index) != RED)
		return;
	JailBoss fighter = JailBoss(player.index);
	int i = fighter.index;
	char wepclassname[64];
	int buttons = GetClientButtons(i);
	
	SetHudTextParams(-1.0, 0.88, 0.35, 90, 255, 90, 255, 0, 0.35, 0.0, 0.1);
	if (!IsPlayerAlive(i)) 
	{
		int obstarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
		if (IsValidClient(obstarget) && GetClientTeam(obstarget) != 3 && obstarget != i)
		{
			if (!(buttons & IN_SCORE))
				ShowSyncHudText(i, rageHUD, "Damage: %d - %N's Damage: %d", fighter.iDamage, obstarget, JailBoss(obstarget).iDamage);
		}
		else 
		{
			if (!(buttons & IN_SCORE))
				ShowSyncHudText(i, rageHUD, "Damage: %d", fighter.iDamage);
		}
		return;
	}
	/*if (HasEntProp(i, Prop_Send, "m_iKillStreak")) {
		int killstreaker = fighter.GetProperty("iDamage") / 500;
		if (killstreaker && GetEntProp(i, Prop_Send, "m_iKillStreak") >= 0)
			SetEntProp(i, Prop_Send, "m_iKillStreak", killstreaker);
	}*/
	TFClassType TFClass = TF2_GetPlayerClass(i);
	int weapon = GetActiveWep(i);
	if (weapon <= MaxClients || !IsValidEntity(weapon) || !GetEdictClassname(weapon, wepclassname, sizeof(wepclassname)))
		strcopy(wepclassname, sizeof(wepclassname), "");
	bool validwep = (!strncmp(wepclassname, "tf_wea", 6, false));
	int index = GetItemIndex(weapon);
	
	switch (TFClass) 
	{	// Chdata's Deadringer Notifier
		case TFClass_Spy:
		{
			if (GetClientCloakIndex(i) == 59)
			{
				int drstatus = TF2_IsPlayerInCondition(i, TFCond_Cloaked) ? 2 : GetEntProp(i, Prop_Send, "m_bFeignDeathReady") ? 1 : 0;
				char s[32];
				switch (drstatus) 
				{
					case 1:
					{
						SetHudTextParams(-1.0, 0.83, 0.35, 90, 255, 90, 255, 0, 0.0, 0.0, 0.0);
						Format(s, sizeof(s), "Status: Feign-Death Ready");
					}
					case 2:
					{
						SetHudTextParams(-1.0, 0.83, 0.35, 255, 64, 64, 255, 0, 0.0, 0.0, 0.0);
						Format(s, sizeof(s), "Status: Dead-Ringered");
					}
					default:
					{
						SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
						Format(s, sizeof(s), "Status: Inactive");
					}
				}
				if (!(buttons & IN_SCORE))
					ShowSyncHudText(i, jumpHUD, "%s", s);
			}
		}
		case TFClass_Medic:
		{
			int medigun = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			char mediclassname[32];
			if (IsValidEdict(medigun) && GetEdictClassname(medigun, mediclassname, sizeof(mediclassname)) && !strcmp(mediclassname, "tf_weapon_medigun", false))
			{
				SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
				int charge = RoundToFloor(GetMediCharge(medigun) * 100);
				if (!(buttons & IN_SCORE))
					ShowSyncHudText(i, jumpHUD, "Ubercharge: %i", charge);
			}
			
			if (weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary))
			{
				int healtarget = GetHealingTarget(i);
				if (IsValidClient(healtarget) && TF2_GetPlayerClass(healtarget) == TFClass_Scout)
					TF2_AddCondition(i, TFCond_SpeedBuffAlly, 0.2);
				if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease") && GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel") > 0.0)
					TF2_AddCondition(i, TFCond_Ubercharged, 1.0); // Fixes Ubercharges ending prematurely on Medics.
			}
		}
		case TFClass_Soldier:
		{
			if (GetIndexOfWeaponSlot(i, TFWeaponSlot_Primary) == 1104)
			{
				SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
				if (!(buttons & IN_SCORE))
					ShowSyncHudText(i, jumpHUD, "Air Strike Damage: %i", fighter.iDamage);
			}
		}
	}
	int living = GetLivingPlayers(RED);
	if (living == 1 && !TF2_IsPlayerInCondition(i, TFCond_Cloaked))
	{
		TF2_AddCondition(i, TFCond_CritOnWin, 0.2);
		int primary = GetPlayerWeaponSlot(i, TFWeaponSlot_Primary);
		if (TFClass == TFClass_Engineer && weapon == primary && StrEqual(wepclassname, "tf_weapon_sentry_revenge", false))
			SetEntProp(i, Prop_Send, "m_iRevengeCrits", 3);
		TF2_AddCondition(i, TFCond_Buffed, 0.2);
		return;
	}
	
	else if (living == 2 && !TF2_IsPlayerInCondition(i, TFCond_Cloaked))
		TF2_AddCondition(i, TFCond_Buffed, 0.2);

	TFCond cond = TFCond_CritOnWin;
	if (TF2_IsPlayerInCondition(i, TFCond_CritCola) && (TFClass == TFClass_Scout || TFClass == TFClass_Heavy))
	{
		TF2_AddCondition(i, cond, 0.2);
		return;
	}
	
	bool addthecrit = false;
	bool addmini = false;
	for (int u = MaxClients; u; --u) 
	{
		if (IsValidClient(u) && IsPlayerAlive(i) && GetHealingTarget(u) == i)
		{
			addmini = true;
			break;
		}
	}
	if (validwep && weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Melee))
	{
		// Slightly longer check but makes sure that any weapon that can backstab will not crit (e.g. Saxxy)
		if (strcmp(wepclassname, "tf_weapon_knife", false))
			addthecrit = true;
	}
	if (validwep && weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Primary)) // Primary weapon crit list
	{
		if (StrStarts(wepclassname, "tf_weapon_compound_bow") ||  // Sniper bows
			StrStarts(wepclassname, "tf_weapon_crossbow") ||  // Medic crossbows
			StrEqual(wepclassname, "tf_weapon_shotgun_building_rescue") ||  // Engineer Rescue Ranger
			StrEqual(wepclassname, "tf_weapon_drg_pomson")) // Engineer Pomson
		{
			addthecrit = true;
		}
	}
	if (validwep && weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary)) // Secondary weapon crit list
	{
		if (StrStarts(wepclassname, "tf_weapon_pistol") ||  // Engineer/Scout pistols
			StrStarts(wepclassname, "tf_weapon_handgun_scout_secondary") ||  // Scout pistols
			StrStarts(wepclassname, "tf_weapon_raygun") ||  //Bison
			StrStarts(wepclassname, "tf_weapon_flaregun") ||  // Flare guns
			StrEqual(wepclassname, "tf_weapon_smg")) // Sniper SMGs minus Cleaner's Carbine
		{
			if (TFClass == TFClass_Scout && cond == TFCond_CritOnWin) cond = TFCond_Buffed;
			int PrimaryIndex = GetIndexOfWeaponSlot(i, TFWeaponSlot_Primary);
			if ((TFClass == TFClass_Pyro && PrimaryIndex == 594) || (IsValidEntity(FindPlayerBack(i, { 642 }, 1))) || (IsValidEntity(FindPlayerBack(i, { 231 }, 1)))) // No crits if using Phlogistinator or Cozy Camper or Darwin's Danger Shield
				addthecrit = false;
			else addthecrit = true;
		}
		if (StrStarts(wepclassname, "tf_weapon_jar") ||  // Jarate/Milk
			StrEqual(wepclassname, "tf_weapon_cleaver")) // Flying Guillotine
		addthecrit = true;
	}
	switch (index) //Specific weapon crit list
	{
		/*case :
		{
			addthecrit = true;
		}*/
		case 997:
		{
			addthecrit = true;
		}
		case 656: //Holiday Punch
		{
			addthecrit = true;
			cond = TFCond_Buffed;
		}
		case 416: //Market Gardener
		{
			addthecrit = false;
		}
		case 307: //caber
		{
			addthecrit = true;
		}
		case 38, 348, 457, 1000: //Axtinguisher, Postal Pummeler, volcano fragment
		{
			addthecrit = false;
		}
		case 609: //scottish handshake
		{
			addthecrit = false;
		}
		case 460: //enforcer
		{
			addthecrit = false;
		}
		case 413: //solemn vow
		{
			addthecrit = false;
		}
		case 11, 199, 425, 1141, 1153, 15003, 15016, 15044, 15047, 15085, 15109, 15132, 15133, 15152:
		{
			if (TFClass == TFClass_Heavy)
			{
				addthecrit = true;
				cond = TFCond_Buffed;
			}
		}
		case 23:
		{	// Crits fucked up for the spy nailgun, had to force it here
			if (TFClass == TFClass_Spy)
				addthecrit = false;
			else cond = TFCond_Buffed;
		}
		case 350: //atomizer
		{
			addthecrit = false;
		}
	}
	
	// if ( TFClass == TFClass_DemoMan && !IsValidEntity(GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary)) )
	if (TFClass == TFClass_DemoMan && JBVSH[DemoShieldCrits].IntValue && validwep && weapon != GetPlayerWeaponSlot(i, TFWeaponSlot_Melee))
	{
		float flShieldMeter = GetEntPropFloat(i, Prop_Send, "m_flChargeMeter");
		
		if (JBVSH[DemoShieldCrits].IntValue >= 1)
		{
			addthecrit = true;
			if (JBVSH[DemoShieldCrits].IntValue == 1 || (JBVSH[DemoShieldCrits].IntValue == 3 && flShieldMeter < 100.0))
				cond = TFCond_Buffed;
			if (JBVSH[DemoShieldCrits].IntValue == 3 && (flShieldMeter < 35.0 || !GetEntProp(i, Prop_Send, "m_bShieldEquipped")))
				addthecrit = false;
		}
	}
	
	if (addthecrit) 
	{
		TF2_AddCondition(i, cond, 0.2);
		if (addmini && cond != TFCond_Buffed)
			TF2_AddCondition(i, TFCond_Buffed, 0.2);
	}
	if (TFClass == TFClass_Spy && validwep && weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Primary))
	{
		if (!TF2_IsPlayerCritBuffed(i)
			&& !TF2_IsPlayerInCondition(i, TFCond_Buffed)
			&& !TF2_IsPlayerInCondition(i, TFCond_Cloaked)
			&& !TF2_IsPlayerInCondition(i, TFCond_Disguised)
			&& !GetEntProp(i, Prop_Send, "m_bFeignDeathReady"))
		{
			TF2_AddCondition(i, TFCond_CritCola, 0.2);
		}
	}
	if (TFClass == TFClass_Engineer
		&& weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Primary)
		&& StrEqual(wepclassname, "tf_weapon_sentry_revenge", false))
	{
		int sentry = FindSentry(i);
		if (IsValidEntity(sentry)) 
		{
			int enemy = GetEntPropEnt(sentry, Prop_Send, "m_hEnemy");
			if (enemy > 0 && GetClientTeam(enemy) == 3) {  // Trying to target minions as well
				SetEntProp(i, Prop_Send, "m_iRevengeCrits", 3);
				TF2_AddCondition(i, TFCond_Kritzkrieged, 0.2);
			}
			else 
			{
				if (GetEntProp(i, Prop_Send, "m_iRevengeCrits"))
					SetEntProp(i, Prop_Send, "m_iRevengeCrits", 0);
				else if (TF2_IsPlayerInCondition(i, TFCond_Kritzkrieged) && !TF2_IsPlayerInCondition(i, TFCond_Healing))
					TF2_RemoveCondition(i, TFCond_Kritzkrieged);
			}
		}
	}
}
/*public void fwdOnBlueNotWardenThink(const JBPlayer player)
{

}*/
public void fwdOnAllBlueThink(const JBPlayer player)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;
	JailBoss base = JailBoss(player.index);
	if (!base.bIsBoss)
		return;
	switch (base.iType) 
	{
		case  - 1: {  }
		case Hale:ToCHale(base).Think();
		case Vagineer:ToCVagineer(base).Think();
		case CBS:ToCChristian(base).Think();
		case HHHjr:ToCHHHJr(base).Think();
		case Bunny:ToCBunny(base).Think();
	}
	/* Adding this so bosses can take minicrits if airborne */
	TF2_AddCondition(base.index, TFCond_GrapplingHookSafeFall, 0.2);
}
/*public void fwdOnWardenThink(const JBPlayer player)
{

}*/
/*public void fwdOnPlayerDied(const JBPlayer victim, const JBPlayer attacker, Event event)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iRoundState") == StateDisabled || JBGameMode_GetProperty("iLRType") != 13)
		return;

	JailBoss vict = JailBoss(victim.index);
	JailBoss atkr = JailBoss(attacker.index);

	int deathflags = event.GetInt("death_flags");
	if (vict.bIsBoss) // If victim is a boss, kill him off
		SetPawnTimer(_BossDeath, 0.1, vict.userid);
	
	if (atkr.bIsBoss && !vict.bIsBoss)
	{
		switch (atkr.iType) 
		{
			case  - 1: {  }
			case Hale:
			{
				if (deathflags & TF_DEATHFLAG_DEADRINGER)
					event.SetString("weapon", "fists");
				else ToCHale(atkr).KilledPlayer(vict, event);
			}
			case Vagineer:ToCVagineer(atkr).KilledPlayer(vict, event);
			case CBS:ToCChristian(atkr).KilledPlayer(vict, event);
			case HHHjr:ToCHHHJr(atkr).KilledPlayer(vict, event);
			case Bunny:ToCBunny(atkr).KilledPlayer(vict, event);
		}
	}

	if (!vict.bIsBoss)
		SetPawnTimer(CheckAlivePlayers, 0.2);
	
	if ( (TF2_GetPlayerClass(vict.index) == TFClass_Engineer) && !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) )
	{
		if (JBVSH[EngieBuildings].IntValue) 
		{
			switch (JBVSH[EngieBuildings].IntValue) 
			{
				case 1: 
				{
					int sentry = FindSentry(vict.index);
					if (sentry != -1) 
					{
						SetVariantInt(GetEntProp(sentry, Prop_Send, "m_iMaxHealth")+8);
						AcceptEntityInput(sentry, "RemoveHealth");
					}
				}
				case 2: 
				{
					for (int ent=MaxClients+1 ; ent<2048 ; ++ent) 
					{
						if (!IsValidEdict(ent)) 
							continue;
						else if (!HasEntProp(ent, Prop_Send, "m_hBuilder"))
							continue;
						else if (GetBuilder(ent) != vict.index)
							continue;

						SetVariantInt(GetEntProp(ent, Prop_Send, "m_iMaxHealth")+8);
						AcceptEntityInput(ent, "RemoveHealth");
					}
				}
			}
		}
	}
}*/
public void fwdOnBuildingDestroyed(const JBPlayer attacker, const int building, Event event)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;
	JailBoss atkr = JailBoss(attacker.index);

	switch (atkr.iType) 
	{
		case  - 1: {  }
		case Hale: 
		{
			event.SetString("weapon", "fists");
			if (!GetRandomInt(0, 3)) 
			{
				strcopy(snd, FULLPATH, HaleSappinMahSentry132);
				EmitSoundToAll(snd, atkr.index);
			}
		}
	}
}
public void fwdOnObjectDeflected(const JBPlayer attacker, const JBPlayer victim, Event event)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;

	//JailBoss airblaster = JailBoss(attacker.index);
	JailBoss airblasted = JailBoss(victim.index);

	switch (airblasted.iType) 
	{
		case  - 1: {  }
		case Hale, CBS, HHHjr, Bunny:airblasted.flRAGE += JBVSH[AirblastRage].FloatValue;
		case Vagineer:
		{
			if (TF2_IsPlayerInCondition(airblasted.index, TFCond_Ubercharged))
				TF2_AddCondition(airblasted.index, TFCond_Ubercharged, 2.0);
			else airblasted.flRAGE += JBVSH[AirblastRage].FloatValue;
		}
	}
}
public void fwdOnPlayerJarated(const JBPlayer attacker, const JBPlayer victim)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13 || JBGameMode_GetProperty("iRoundState") != StateRunning)
		return;

	JailBoss atkr = JailBoss(attacker.index);
	JailBoss vict = JailBoss(victim.index);

	ManagePlayerJarated(atkr, vict);
}
public void fwdOnUberDeployed(const JBPlayer attacker, const JBPlayer victim)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iRoundState") != 13)
		return;

	JailBoss medic = JailBoss(attacker.index);
	JailBoss patient = JailBoss(victim.index);

	ManageUberDeploy(medic, patient);
}
public void fwdOnPlayerSpawned(const JBPlayer player, Event event)
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;

	JailBoss spawn = JailBoss(player.index);

	if (spawn.bIsBoss)
		return;

	SetVariantString(""); AcceptEntityInput(spawn.index, "SetCustomModel");

	/*if (player.bIsBoss && JBGameMode_GetProperty("iRoundState") < StateEnding && JBGameMode_GetProperty("iRoundState") != StateDisabled)
	{
		if (GetClientTeam(player.index) != BLU)
			player.ForceTeamChange(BLU);
		player.ConvertToBoss();
		if (player.iHealth == 0)
			player.iHealth = player.iMaxHealth);
	}*/

	if (JBGameMode_GetProperty("iRoundState") > StateDisabled)
	{
		if (GetClientTeam(spawn.index) != RED)
			spawn.ForceTeamChange(RED);
		SetPawnTimer( PrepPlayers, 0.2, spawn );
	}
}
public void fwdOnManageTimeLeft()
{
	if (!bEnabled.BoolValue || JBGameMode_GetProperty("iLRType") != 13)
		return;

	JBGameMode_SetProperty("iTimeLeft", 600);
}

public void CheckJBHooks()
{
	if (!JB_HookEx(OnLRRoundActivate, fwdOnLRRoundActivate))
		LogError("Error Loading OnLRRoundActivate Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnManageRoundStart, fwdOnManageRoundStart))
		LogError("Error Loading OnManageRoundStart, Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnLRRoundEnd, fwdOnLRRoundEnd))
		LogError("Error Loading OnLRRoundEnd Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnManageRoundEnd, fwdOnManageRoundEnd))
		LogError("Error Loading OnManageRoundEnd Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnWardenGet, fwdOnWardenGet))
		//LogError("Error Loading OnWardenGet Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnClientTouch, fwdOnClientTouch))
		//LogError("Error Loading OnClientTouch Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnRedThink, fwdOnRedThink))
		LogError("Error Loading OnRedThink Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnBlueNotWardenThink, fwdOnBlueNotWardenThink))
		//LogError("Error Loading OnBlueNotWardenThink Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnAllBlueThink, fwdOnAllBlueThink))
		LogError("Error Loading OnAllBlueThink Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnWardenThink, fwdOnWardenThink))
		//LogError("Error Loading OnWardenThink Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnPlayerDied, fwdOnPlayerDied))
		//LogError("Error loading OnPlayerDied Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnBuildingDestroyed, fwdOnBuildingDestroyed))
		LogError("Error loading OnBuildingDestroyed Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnObjectDeflected, fwdOnObjectDeflected))
		LogError("Error loading OnObjectDeflected Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnPlayerJarated, fwdOnPlayerJarated))
		LogError("Error loading OnPlayerJarated Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnUberDeployed, fwdOnUberDeployed))
		LogError("Error loading OnUberDeployed Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnPlayerSpawned, fwdOnPlayerSpawned))
		LogError("Error loading OnPlayerSpawned Forwards for JB VSH Sub-Plugin!");
	if (!JB_HookEx(OnManageTimeLeft, fwdOnManageTimeLeft))
		LogError("Error loading OnManageTimeLeft Forwards for JB VSH Sub-Plugin!");
	//if (!JB_HookEx(OnMusicPlay, fwdOnMusicPlay))
		//LogError("Error loading OnMusicPlay Forwards for JB VSH Sub-Plugin!");
}