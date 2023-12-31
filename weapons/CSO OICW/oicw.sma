#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

enum{ PRIMARIA=1, SECUNDARIA, KNIFE, ESPECIALES, MAX_ARMS };
native zp_arma(const name[], level, reset, categoria, admin, const adm_tipo[]);
forward dar_arma(id, item);

new g_item;


#define PLUGIN "OICW"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define V_MODEL "models/v_oicw.mdl"
#define P_MODEL "models/p_oicw.mdl"
//#define W_MODEL "models/w_oicw.mdl"
#define S_MODEL "models/s_oicw.mdl"

#define CSW_OICW CSW_M4A1
#define weapon_oicw "weapon_m4a1"
#define OLD_W_MODEL "models/w_m4a1.mdl"
#define WEAPON_EVENT "events/m4a1.sc"
#define WEAPON_SECRETCODE 1992

#define DAMAGE 25
#define GRENADE_DAMAGE 500
#define GRENADE_RADIUS 300
#define BPAMMO 90
#define GRENADE_DEFAULT 6
#define RELOAD_TIME 3.5
#define GRENADE_RELOAD_TIME 3.0
#define CHANGE_TIME 1.0

#define TASK_CHANGE 1987

new const WeaponSounds[][] = 
{
	"weapons/oicw-1.wav",
	"weapons/oicw_grenade_shoot1.wav",
	"weapons/oicw_foley1.wav",
	"weapons/oicw_move_carbine.wav",
	"weapons/oicw_move_grenade.wav"
}

new const WeaponResources[1][] =
{
	"sprites/weapon_oicw.txt"
}

enum
{
	ANIM_CARBINE_IDLE = 0,
	ANIM_CARBINE_SHOOT1,
	ANIM_CARBINE_SHOOT2,
	ANIM_CARBINE_SHOOT3,
	ANIM_CARBINE_RELOAD,
	ANIM_CARBINE_DRAW,
	ANIM_GRENADE_IDLE,
	ANIM_GRENADE_SHOOT1,
	ANIM_GRENADE_SHOOT2,
	ANIM_MOVE_TO_GRENADE,
	ANIM_MOVE_TO_CARBINE
}

enum
{
	OICW_MODE_CARBINE = 1,
	OICW_MODE_GRENADE
}

new g_Had_Oicw[33], g_WeaponMode[33], g_IsChanging[33], g_GrenadeAmmo[33]
new g_old_weapon[33], g_smokepuff_id, g_ham_bot, shells_model, g_oiwc_event, spr_trail, g_expspr_id, g_SmokeSprId

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_Think, "fw_Think")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")		
	RegisterHam(Ham_Weapon_Reload, weapon_oicw, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_oicw, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_oicw, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_oicw, "fw_Item_AddToPlayer_Post", 1)
	register_logevent("event_round_start", 2, "1=Round_Start")
	//register_clcmd("admin_get_oicw", "Get_OICW", ADMIN_KICK)
	register_clcmd("weapon_oicw", "hook_weapon")
	g_item = zp_arma("Oicw", 6, 0, PRIMARIA, ADMIN_ALL, "");
}
public event_round_start(){
	for(new i=1; i<= get_maxplayers(); ++i)
		Remove_OICW(i)
}
	
public dar_arma(id, item){
	if(item != g_item)
		return;
	
	Get_OICW(id);
}
public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	//engfunc(EngFunc_PrecacheModel, P_MODEL)
	//engfunc(EngFunc_PrecacheModel, W_MODEL)
	engfunc(EngFunc_PrecacheModel, S_MODEL)
	
	new i 
	for(i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	
	g_smokepuff_id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	shells_model = engfunc(EngFunc_PrecacheModel, "models/rshell.mdl")
	spr_trail = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	g_expspr_id = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr")
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name))
		g_oiwc_event = get_orig_retval()		
}

public Get_OICW(id)
{
	if(!is_user_alive(id))
		return
		
	g_Had_Oicw[id] = 1
	g_WeaponMode[id] = OICW_MODE_CARBINE
	g_IsChanging[id] = 0
	g_GrenadeAmmo[id] = GRENADE_DEFAULT
	
	fm_give_item(id, weapon_oicw)
	
	cs_set_user_bpammo(id, CSW_OICW, BPAMMO)
	update_ammo(id)
}

public update_ammo(id)
{
	if(!is_user_alive(id))
		return
	
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_oicw, id)
	if(pev_valid(weapon_ent))
	{
		engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
		write_byte(1)
		write_byte(CSW_OICW)
		write_byte(cs_get_weapon_ammo(weapon_ent))
		message_end()		
	}
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(cs_get_user_bpammo(id, CSW_OICW))
	message_end()
}

public Remove_OICW(id)
{
	if(!is_user_connected(id))
		return
		
	g_Had_Oicw[id] = 0
}

public hook_weapon(id)
{
	engclient_cmd(id, weapon_oicw)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	if((get_user_weapon(id) == CSW_OICW && g_Had_Oicw[id]) && g_old_weapon[id] != CSW_OICW)
	{ // Draw
		set_pev(id, pev_viewmodel2, V_MODEL)
		//set_pev(id, pev_weaponmodel2, P_MODEL)
		
		if(g_WeaponMode[id] == OICW_MODE_GRENADE)
		{
			static Ent; Ent = fm_get_user_weapon_entity(id, CSW_OICW)
			update_ammo2(id, pev(Ent, pev_iuser3), pev(Ent, pev_iuser4))
		}
		g_WeaponMode[id] = OICW_MODE_CARBINE
		
		set_weapon_anim(id, ANIM_CARBINE_DRAW)
	} else {
		g_IsChanging[id] = 0
	}
	
	g_old_weapon[id] = get_user_weapon(id)
}

public fw_Think(ent)
{
	if(!pev_valid(ent))
		return
		
	static Classname[32]
	pev(ent, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "grenade2"))
		return
		
	Make_Explosion(ent)
	engfunc(EngFunc_RemoveEntity, ent)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_OICW && g_Had_Oicw[id])
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_OICW || !g_Had_Oicw[invoker])
		return FMRES_IGNORED
	
	if(eventid == g_oiwc_event)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
		set_weapon_anim(invoker, random_num(ANIM_CARBINE_SHOOT1, ANIM_CARBINE_SHOOT3))
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		make_shell(invoker)
		
		return FMRES_SUPERCEDE
	} 
	
	return FMRES_HANDLED
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_oicw, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(g_Had_Oicw[iOwner])
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, OLD_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) != CSW_OICW || !g_Had_Oicw[id])	
		return FMRES_IGNORED
		
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	
	if(NewButton & IN_ATTACK)
	{
		if(g_IsChanging[id])
		{
			NewButton &= ~IN_ATTACK
			set_uc(uc_handle, UC_Buttons, NewButton)
			
			return FMRES_IGNORED
		}
		
		if(g_WeaponMode[id] != OICW_MODE_GRENADE)
			return FMRES_IGNORED
			
		NewButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, NewButton)
		
		Shoot_Grenade_Handle(id)
	} 
	
	if(NewButton & IN_ATTACK2) {
		NewButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, NewButton)
		
		NewButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, NewButton)
		
		if((pev(id, pev_oldbuttons) & IN_ATTACK2))
			return FMRES_IGNORED
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
			
		g_IsChanging[id] = 1
			
		set_weapons_timeidle(id, CHANGE_TIME + 0.1)
		set_player_nextattack(id, CHANGE_TIME)	
			
		set_weapon_anim(id, g_WeaponMode[id] == OICW_MODE_CARBINE ? ANIM_MOVE_TO_GRENADE : ANIM_MOVE_TO_CARBINE)
		set_task(CHANGE_TIME, "OICW_CHANGE_COMPLETE", id+TASK_CHANGE)
	}
	
	return FMRES_IGNORED
}

public OICW_CHANGE_COMPLETE(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_OICW || !g_Had_Oicw[id])	
		return
	if(!g_IsChanging[id])
		return
		
	g_IsChanging[id] = 0
			
	if(g_WeaponMode[id] == OICW_MODE_CARBINE) g_WeaponMode[id] = OICW_MODE_GRENADE
	else if(g_WeaponMode[id] == OICW_MODE_GRENADE) g_WeaponMode[id] = OICW_MODE_CARBINE
	
	Change_Complete(id, g_WeaponMode[id])
}

public Shoot_Grenade_Handle(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	if(g_WeaponMode[id] != OICW_MODE_GRENADE)	
		return
	if(g_IsChanging[id])
		return
	if(!g_GrenadeAmmo[id])
	{
		client_print(id, print_center, "Out Of Ammo")
		set_pdata_float(id, 83, 1.0, 5)
		
		return
	}
	
	g_GrenadeAmmo[id]--
	update_ammo2(id, -1, g_GrenadeAmmo[id])
	
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, "weapon_knife", id)
	if(pev_valid(weapon_ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, weapon_ent)	
	
	if(g_GrenadeAmmo[id]) 
	{
		set_weapons_timeidle(id, GRENADE_RELOAD_TIME + 0.1)
		set_player_nextattack(id, GRENADE_RELOAD_TIME)
		
		set_weapon_anim(id, ANIM_GRENADE_SHOOT1)
		emit_sound(id, CHAN_WEAPON, WeaponSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
	} else {
		set_weapons_timeidle(id, (GRENADE_RELOAD_TIME / 3.0) + 0.1)
		set_player_nextattack(id, (GRENADE_RELOAD_TIME / 3.0))
		
		set_weapon_anim(id, ANIM_GRENADE_SHOOT2)
		emit_sound(id, CHAN_WEAPON, WeaponSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-2.0, -4.0)
	PunchAngles[2] = random_float(5.0, -5.0)
	
	set_pev(id, pev_punchangle, PunchAngles)
	
	Create_Grenade(id)
}

public Create_Grenade(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Angles[3]
	
	get_weapon_attachment(id, Origin, 24.0)
	pev(id, pev_angles, Angles)
	
	set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ent, pev_solid, SOLID_BBOX)
	set_pev(Ent, pev_nextthink, get_gametime() + 2.5)
	
	set_pev(Ent, pev_classname, "grenade2")
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_owner, id)
	
	// Create Velocity
	static Float:Velocity[3], Float:TargetOrigin[3]
	
	fm_get_aim_origin(id, TargetOrigin)
	get_speed_vector(Origin, TargetOrigin, 900.0, Velocity)
	
	set_pev(Ent, pev_velocity, Velocity)
	
	// Make a Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent) // entity
	write_short(spr_trail) // sprite
	write_byte(20)  // life
	write_byte(2)  // width
	write_byte(200) // r
	write_byte(200);  // g
	write_byte(200);  // b
	write_byte(200); // brightness
	message_end();
}

public Make_Explosion(ent)
{
	static Float:Origin[3]
	pev(ent, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_expspr_id)	// sprite index
	write_byte(30)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(0)	// flags
	message_end()
	
	// Put decal on "world" (a wall)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()	
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_SMOKE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokeSprId)	// sprite index 
	write_byte(30)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	static Float:Origin2[3]
	
	for(new i = 0; i < get_maxplayers(); i++)
	{
		if(!is_user_alive(i))
			continue
		pev(i, pev_origin, Origin2)
		if(get_distance_f(Origin, Origin2) > float(GRENADE_RADIUS))
			continue

		ExecuteHamB(Ham_TakeDamage, i, 0, pev(ent, pev_owner), float(GRENADE_DAMAGE), DMG_BULLET)
	}
}

public Change_Complete(id, Mode)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_OICW)
	if(!pev_valid(Ent))
		return
		
	if(Mode == OICW_MODE_CARBINE)
	{
		update_ammo2(id, pev(Ent, pev_iuser3), pev(Ent, pev_iuser4))
	} else if(Mode == OICW_MODE_GRENADE) {
		set_pev(Ent, pev_iuser3, cs_get_weapon_ammo(Ent))
		set_pev(Ent, pev_iuser4, cs_get_user_bpammo(id, CSW_OICW))
		
		update_ammo2(id, -1, g_GrenadeAmmo[id])
	}
}

public fw_TraceAttack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(attacker) || !is_user_connected(attacker))
		return HAM_IGNORED	
	if(get_user_weapon(attacker) != CSW_OICW || !g_Had_Oicw[attacker])
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
		
	if(!is_user_alive(ent))
	{
		make_bullet(attacker, flEnd)
		fake_smoke(attacker, ptr)
	}
		
	SetHamParamFloat(3, float(DAMAGE))	

	return HAM_HANDLED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!g_Had_Oicw[id])
		return HAM_IGNORED
	if(g_WeaponMode[id] == OICW_MODE_GRENADE)
		return HAM_SUPERCEDE
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!g_Had_Oicw[id])
		return HAM_IGNORED
	if(g_WeaponMode[id] == OICW_MODE_GRENADE)
		return HAM_IGNORED
		
	if((get_pdata_int(ent, 54, 4) == 1) && g_WeaponMode[id] == OICW_MODE_CARBINE)
	{ // Reload
		set_weapon_anim(id, ANIM_CARBINE_RELOAD)
		set_pdata_float(id, 83, RELOAD_TIME, 5)
	}
	
	return HAM_HANDLED
}

public fw_Weapon_WeaponIdle_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!g_Had_Oicw[id])
		return HAM_IGNORED
		
	if(get_pdata_float(ent, 48, 4) <= 0.1) 
	{
		set_weapon_anim(id, g_WeaponMode[id] == OICW_MODE_CARBINE ? ANIM_CARBINE_IDLE : ANIM_GRENADE_IDLE)
		set_pdata_float(ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		g_Had_Oicw[id] = 1
		set_pev(ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList"), .player = id)
	write_string(g_Had_Oicw[id] == 1 ? "weapon_oicw" : "weapon_m4a1")
	write_byte(4) // PrimaryAmmoID
	write_byte(90) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(6) // NumberInSlot (1...N)
	write_byte(g_Had_Oicw[id] == 1 ? CSW_OICW : CSW_M4A1) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new decal = random_num(41, 45)
	const loop_time = 2
	
	static Body, Target
	get_user_aiming(id, Target, Body, 999999)
	
	if(is_user_connected(Target))
		return
	
	for(new i = 0; i < loop_time; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

public fake_smoke(id, trace_result)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(trace_result, TR_vecEndPos, vecSrc)
	get_tr2(trace_result, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_smokepuff_id)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	new Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	new Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	new Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	new Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock set_weapon_anim(id, anim)
{
	if(!is_user_alive(id))
		return
	
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

public make_shell(id)
{
	static Float:player_origin[3], Float:origin[3], Float:origin2[3], Float:gunorigin[3], Float:oldangles[3], Float:v_forward[3], Float:v_forward2[3], Float:v_up[3], Float:v_up2[3], Float:v_right[3], Float:v_right2[3], Float:viewoffsets[3];
	
	pev(id,pev_v_angle, oldangles); pev(id,pev_origin,player_origin); pev(id, pev_view_ofs, viewoffsets);

	engfunc(EngFunc_MakeVectors, oldangles)
	
	global_get(glb_v_forward, v_forward); global_get(glb_v_up, v_up); global_get(glb_v_right, v_right);
	global_get(glb_v_forward, v_forward2); global_get(glb_v_up, v_up2); global_get(glb_v_right, v_right2);
	
	xs_vec_add(player_origin, viewoffsets, gunorigin);
	
	xs_vec_mul_scalar(v_forward, 10.3, v_forward); xs_vec_mul_scalar(v_right, 2.9, v_right);
	xs_vec_mul_scalar(v_up, -3.7, v_up);
	xs_vec_mul_scalar(v_forward2, 10.0, v_forward2); xs_vec_mul_scalar(v_right2, 3.0, v_right2);
	xs_vec_mul_scalar(v_up2, -4.0, v_up2);
	
	xs_vec_add(gunorigin, v_forward, origin);
	xs_vec_add(gunorigin, v_forward2, origin2);
	xs_vec_add(origin, v_right, origin);
	xs_vec_add(origin2, v_right2, origin2);
	xs_vec_add(origin, v_up, origin);
	xs_vec_add(origin2, v_up2, origin2);

	static Float:velocity[3]
	get_speed_vector(origin2, origin, random_float(140.0, 160.0), velocity)

	static angle; angle = random_num(0, 360)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_MODEL)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord,origin[1])
	engfunc(EngFunc_WriteCoord,origin[2])
	engfunc(EngFunc_WriteCoord,velocity[0])
	engfunc(EngFunc_WriteCoord,velocity[1])
	engfunc(EngFunc_WriteCoord,velocity[2])
	write_angle(angle)
	write_short(shells_model)
	write_byte(1)
	write_byte(20)
	message_end()
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock set_weapons_timeidle(id, Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	new entwpn = fm_get_user_weapon_entity(id, CSW_OICW)
	if(!pev_valid(entwpn)) 
		return
	
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 1.0, 4)
}

stock set_player_nextattack(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, 83, nexttime, 5)
}

public update_ammo2(id, ammo, bpammo)
{
	if(!is_user_alive(id))
		return
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_OICW)
	write_byte(ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(bpammo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_OICW, bpammo)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
