#define SPAWN 			"ui/halloween_boss_summoned_fx.wav"
#define SPAWNRUMBLE 	"ui/halloween_boss_summon_rumble.wav"
#define SPAWNVO 		"vo/halloween_boss/knight_spawn.wav"
#define BOO 			"vo/halloween_boss/knight_alert.wav"
#define DEATH 			"ui/halloween_boss_defeated_fx.wav"
#define DEATHVO 		"vo/halloween_boss/knight_death02.wav"
#define DEATHVO2 		"vo/halloween_boss/knight_dying.wav"
#define LEFTFOOT 		"player/footsteps/giant1.wav"
#define RIGHTFOOT 		"player/footsteps/giant2.wav"

methodmap CHHHDay < JailGameMode
{
	public CHHHDay( JailGameMode handle )
	{
		return view_as< CHHHDay >(handle);
	}

	public void Initialize()
	{
		this.bIsWardenLocked = true;
		this.bIsWarday = true;
		this.bDisableCriticals = true;
		CPrintToChatAll("{burlywood}BOO!");
		EmitSoundToAll(SPAWN);
		EmitSoundToAll(SPAWNRUMBLE);
		this.DoorHandler(OPEN);
	}

	public void Activate( const JailFighter player )
	{
		player.MakeHorsemann();	// Fuck server commands, hard coding feels more solid
	}

	public Action HookSound( const JailFighter player, char sample[PLATFORM_MAX_PATH], int &entity )
	{
		if (player.bIsHHH)
		{
			if (!strncmp(sample, "vo", 2, false))
				return Plugin_Handled;
			
			if (strncmp(sample, "player/footsteps/", 17, false) != -1)
			{
				if (StrContains(sample, "1.wav", false) != -1 || StrContains(sample, "3.wav", false) != -1) 
					sample = LEFTFOOT;
				else if (StrContains(sample, "2.wav", false) != -1 || StrContains(sample, "4.wav", false) != -1) 
					sample = RIGHTFOOT;
				EmitSoundToAll(sample, entity);
				return Plugin_Changed;
			}
		}
		return Plugin_Continue;
	}

	public void Terminate( Event event )
	{
		EmitSoundToAll(DEATH);
		EmitSoundToAll(DEATHVO);
		EmitSoundToAll(DEATHVO2);
	}

	public void ManageEnd( const JailFighter player )
	{
		if (player.bIsHHH)
			SetPawnTimer(UnHorsemannify, 1.0, player);
	}

	public void ManageDeath( const JailFighter attacker, const JailFighter victim, Event event )
	{
		if (victim.bIsHHH)
		{
			EmitSoundToAll(DEATHVO, victim.index);
			SetPawnTimer(UnHorsemannify, 0.2, victim);
		}
	}
};

public CHHHDay ToCHHHDay( JailGameMode handle )
{
	return view_as< CHHHDay >(handle);
}

public void HHHDayDownload()
{
	PrecacheModel(HHH, true);
	PrecacheModel(AXE, true);
	PrecacheSound(SPAWN, true);
	PrecacheSound(SPAWNRUMBLE, true);
	PrecacheSound(SPAWNVO, true);
	PrecacheSound(BOO, true);
	PrecacheSound(DEATH, true);
	PrecacheSound(DEATHVO, true);
	PrecacheSound(DEATHVO2, true);
	PrecacheSound(LEFTFOOT, true);
	PrecacheSound(RIGHTFOOT, true);
}