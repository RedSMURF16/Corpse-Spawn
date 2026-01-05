/*
*
*	Corpse Spawn by RedSMURF
*
*
*	Description:
*       This plugins allows dynamic corpse entities to affect players
*       Corpses can apply effects such as Poison, Speed/Gravity modification and Forced weapon switching,
*       All effects are applied only to players within each corpse's configurable effect radius eCorpse[CORPSE_RADIUS],
*       Each corpse also requires a manually set bounding box to match the model, which may be difficult for non-coders,
*       The plugin already comes with a rich set of preconfigured corpses ready to use.
*
*	Cvars:
*		None
*
*	Commands:
*       say /cs                         "Opens the Corpse Spawn menu."
*       say_team /cs                    "Opens the Corpse Spawn menu."
*       say /corpse                     "Opens the Corpse Spawn menu."
*       say_team /corpse                "Opens the Corpse Spawn menu."
*       cs_reload                       "Reloads the configuration file."
*       corpse_reload                   "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Added corpse regeneration effect, improved some logic.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT     32
#define FLOAT_MAX   1.0e10
#define TASK_ACTION 1248
#define TASK_EFFECT 8421

new const PLUGIN_VERSION[]          = "1.1"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "CorpseSpawn_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CORPSE
}

enum
{
    FLAG_SOLID      = (1 << 0),
    FLAG_ANIM       = (1 << 1),
    FLAG_SPEED      = (1 << 2),
    FLAG_GRAVITY    = (1 << 3),
    FLAG_POISON     = (1 << 4),
    FLAG_REGEN      = (1 << 5),
    FLAG_WEAPON     = (1 << 6),

    FLAG_SHOW       = (1 << 7),
    FLAG_GROUND     = (1 << 8),
    FLAG_SELECT     = (1 << 9)
}

enum
{
    SHOW_DEFAULT,
    SHOW_FORCE_SHOW,
    SHOW_FORCE_HIDE
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],

    bool:SETTING_CORPSE_LOAD,
    bool:SETTING_CORPSE_NOCLIP,
    bool:SETTING_CORPSE_SOLID,
    bool:SETTING_CORPSE_ANIM,
    bool:SETTING_CORPSE_ACTION,
    bool:SETTING_CORPSE_EFFECT,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_EFFECT_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA,

    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],

    SETTING_COLOR_SELECT[3]
}

enum _:CORPSE
{
    CORPSE_ID,
    CORPSE_ITEM,
    CORPSE_SHOW,
    CORPSE_FLAGS,
    CORPSE_TEAM,
    CORPSE_NAME[MAX_VALUE_LENGTH],
    CORPSE_MODEL[MAX_RESOURCE_PATH_LENGTH],
    Float:CORPSE_ORIGIN[3],
    Float:CORPSE_ANGLES[3],
    Float:CORPSE_MINS[3],
    Float:CORPSE_MAXS[3],
    Float:CORPSE_SPAWN_CHANCE,

    CORPSE_SEQUENCE,
    Float:CORPSE_FRAME,
    Float:CORPSE_FRAMERATE,

    Float:CORPSE_RADIUS,
    Float:CORPSE_SPEED,
    Float:CORPSE_GRAVITY,
    Float:CORPSE_POISON_MIN,
    Float:CORPSE_POISON_MAX,
    Float:CORPSE_POISON_DELAY_MIN,
    Float:CORPSE_POISON_DELAY_MAX,
    Float:CORPSE_POISON_DURATION_MIN,
    Float:CORPSE_POISON_DURATION_MAX,
    Float:CORPSE_REGEN_MIN,
    Float:CORPSE_REGEN_MAX,
    Float:CORPSE_REGEN_DELAY_MIN,
    Float:CORPSE_REGEN_DELAY_MAX,
    Float:CORPSE_REGEN_DURATION_MIN,
    Float:CORPSE_REGEN_DURATION_MAX,

    CORPSE_WEAPON_LIST[31],
    CORPSE_WEAPON_LIST_COUNT
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CORPSE_GHOST,
    PDATA_CORPSE_MENU,
    PDATA_CORPSE_CLOSEST,
    PDATA_CORPSE_SPEED[MAX_ENT],
    PDATA_CORPSE_SPEED_COUNT,
    PDATA_CORPSE_GRAVITY_COUNT,
    PDATA_CORPSE_POISON[MAX_ENT],
    PDATA_CORPSE_POISON_COUNT,
    PDATA_CORPSE_REGEN[MAX_ENT],
    PDATA_CORPSE_REGEN_COUNT,
    bool:PDATA_CORPSE_ACTION,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,
    Float:PDATA_BASE_SPEED,
    Float:PDATA_BASE_GRAVITY,
    Float:PDATA_CORPSE_POISON_NEXT[MAX_ENT],
    Float:PDATA_CORPSE_POISON_END[MAX_ENT],
    Float:PDATA_CORPSE_REGEN_NEXT[MAX_ENT],
    Float:PDATA_CORPSE_REGEN_END[MAX_ENT]
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_SHOW,
    MENU_POISON,
    MENU_REGEN,
    MENU_WEAPON,
    MENU_TEAM,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_SHOW = 4,
    ROOT_POISON,
    ROOT_REGEN,
    ROOT_WEAPON,
    ROOT_TEAM,
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SHOW_NEXT,
    SHOW_BACK,

    SHOW_CURRENT = 3,
    SHOW_ALL_SHOW,
    SHOW_ALL_HIDE,
    SHOW_ALL_DEFAULT
}

enum
{
    POISON_NEXT,
    POISON_BACK,

    POISON_CURRENT = 3,
    POISON_ALL_ACTIVE,
    POISON_ALL_INACTIVE
}

enum
{
    REGEN_NEXT,
    REGEN_BACK,

    REGEN_CURRENT = 3,
    REGEN_ALL_ACTIVE,
    REGEN_ALL_INACTIVE
}

enum
{
    WEAPON_NEXT,
    WEAPON_BACK,

    WEAPON_CURRENT = 3,
    WEAPON_ALL_ACTIVE,
    WEAPON_ALL_INACTIVE
}

enum
{
    TEAM_NEXT,
    TEAM_BACK,

    TEAM_CURRENT = 3,
    TEAM_ALL_NONE,
    TEAM_ALL_T,
    TEAM_ALL_CT,
    TEAM_ALL_BOTH
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,

    ROTATE_GROUND = 3,
    ROTATE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerShow",
    "menuHandlerPoison",
    "menuHandlerRegen",
    "menuHandlerWeapon",
    "menuHandlerTeam",
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szShow[][] = {"CORPSE_DEFAULT", "CORPSE_SHOWN", "CORPSE_HIDDEN"}
new g_szShowChat[][] = {"CORPSE_CHAT_DEFAULT", "CORPSE_CHAT_SHOWN", "CORPSE_CHAT_HIDDEN"}
new g_szShowColor[][] = {"\d", "\y", "\r"}
new g_szTeam[][] = {"CORPSE_NONE", "CORPSE_T", "CORPSE_CT", "CORPSE_BOTH"}
new g_szTeamChat[][] = {"CORPSE_CHAT_NONE", "CORPSE_CHAT_T", "CORPSE_CHAT_CT", "CORPSE_CHAT_BOTH"}

new g_szCN[] = "CorpseSpawn"

new Array:g_aCorpse,
    Array:g_aCorpseConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iCorpse,
    g_iCorpseConfig,
    g_iDamage

public plugin_init()
{
    register_plugin("Corpse Spawn", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /cs",           "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /cs",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say /corpse",       "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /corpse",  "cmdMenu", ADMIN_RCON)
    register_concmd("cs_reload",        "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_concmd("corpse_reload",    "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("CorpseSpawn.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "fwdResetMaxSpeedPlayer", 1)

    register_event("HLTV", "eventHLTV", "a", "1=0", "2=0")
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    g_iDamage = get_user_msgid("Damage")

    if ( g_eSettings[SETTING_CORPSE_ACTION] )
        set_task(g_eSettings[SETTING_GHOST_FREQ], "corpseTask", TASK_ACTION, .flags = "b")

    if ( g_eSettings[SETTING_CORPSE_EFFECT] )
        set_task(g_eSettings[SETTING_EFFECT_FREQ], "corpseEffect", TASK_EFFECT, .flags = "b")

    corpseInit()
}

public plugin_precache()
{
    g_aCorpse       = ArrayCreate(CORPSE)
    g_aCorpseConfig = ArrayCreate(CORPSE)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCorpse)
    ArrayDestroy(g_aCorpseConfig)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    if ( !g_eSettings[SETTING_CORPSE_ACTION] )
        client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_ACTION")

    corpseSound(id, SOUND_MENU_NAV)
    corpseMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_CORPSE_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1
    || equal(szCmd, "invnext")
    || equal(szCmd, "invprev")
    || equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

public eventHLTV()
{
    new iPlayers[MAX_PLAYERS], iNum, id
    get_players(iPlayers, iNum, "a")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        corpseReset(id)
    }
}

public eventRoundStart()
{
    if ( !g_iCorpse )
        return PLUGIN_HANDLED

    new eCorpse[CORPSE]

    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)

        if ( eCorpse[CORPSE_SHOW] != SHOW_DEFAULT )
            continue

        if ( eCorpse[CORPSE_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
        {
            eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
            if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
        }
        else
        {
            eCorpse[CORPSE_FLAGS] &= ~(FLAG_SHOW | FLAG_POISON)
            if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_NOT)
        }

        ArraySetArray(g_aCorpse, i, eCorpse)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        new iPlayers[MAX_PLAYERS], iNum
        get_players(iPlayers, iNum, "ch")

        for ( new i = 0; i < iNum; i ++ )
            UpdateData(iPlayers[i])

        ArrayClear(g_aCorpseConfig)
        g_iCorpseConfig = 0
    }

    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/CorpseSpawn.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        eCorpse[CORPSE], iSection = SECTION_NONE, iLine, iWeapon

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iCorpseConfig )
                            ArrayPushArray(g_aCorpseConfig, eCorpse)

                        copy(eCorpse[CORPSE_NAME], charsmax(eCorpse[CORPSE_NAME]), szData)
                        copy(eCorpse[CORPSE_MODEL], charsmax(eCorpse[CORPSE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        xs_vec_copy(Float:{0.0, 0.0, 0.0}, eCorpse[CORPSE_MINS])
                        xs_vec_copy(Float:{0.0, 0.0, 0.0}, eCorpse[CORPSE_MAXS])
                        eCorpse[CORPSE_FLAGS]               = 0
                        eCorpse[CORPSE_TEAM]                = TEAM_BOTH
                        eCorpse[CORPSE_SPAWN_CHANCE]        = 1.0
                        eCorpse[CORPSE_SEQUENCE]            = 0
                        eCorpse[CORPSE_FRAME]               = 0.0
                        eCorpse[CORPSE_FRAMERATE]           = 1.0
                        eCorpse[CORPSE_RADIUS]              = 75.0
                        eCorpse[CORPSE_SPEED]               = 1.0
                        eCorpse[CORPSE_GRAVITY]             = 1.0
                        eCorpse[CORPSE_POISON_MIN]          = 1.0
                        eCorpse[CORPSE_POISON_MAX]          = 1.0
                        eCorpse[CORPSE_POISON_DELAY_MIN]    = 1.0
                        eCorpse[CORPSE_POISON_DELAY_MAX]    = 1.0
                        eCorpse[CORPSE_POISON_DURATION_MIN] = 1.0
                        eCorpse[CORPSE_POISON_DURATION_MAX] = 1.0
                        eCorpse[CORPSE_REGEN_MIN]           = 1.0
                        eCorpse[CORPSE_REGEN_MAX]           = 1.0
                        eCorpse[CORPSE_REGEN_DELAY_MIN]     = 1.0
                        eCorpse[CORPSE_REGEN_DELAY_MAX]     = 1.0
                        eCorpse[CORPSE_REGEN_DURATION_MIN]  = 1.0
                        eCorpse[CORPSE_REGEN_DURATION_MAX]  = 1.0

                        for ( new i = 0; i < sizeof(eCorpse[CORPSE_WEAPON_LIST]); i ++ )
                            eCorpse[CORPSE_WEAPON_LIST][i] = 0

                        iSection = SECTION_CORPSE
                        g_iCorpseConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                        {
                            copy(g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]), szValue)
                            if ( !g_bFileWasRead ) precache_model(g_eSettings[SETTING_DEFAULT_MODEL])
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_LOAD") )
                        {
                            g_eSettings[SETTING_CORPSE_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_NOCLIP") )
                        {
                            g_eSettings[SETTING_CORPSE_NOCLIP] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_SOLID") )
                        {
                            g_eSettings[SETTING_CORPSE_SOLID] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_ANIM") )
                        {
                            g_eSettings[SETTING_CORPSE_ANIM] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_ACTION") )
                        {
                            g_eSettings[SETTING_CORPSE_ACTION] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CORPSE_EFFECT") )
                        {
                            g_eSettings[SETTING_CORPSE_EFFECT] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_EFFECT_FREQ") )
                        {
                            g_eSettings[SETTING_EFFECT_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                        {
                            g_eSettings[SETTING_GHOST_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_SELECT") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_SELECT][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_SELECT][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_SELECT][2] = str_to_num(szValue)
                        }
                    }
                    case SECTION_CORPSE:
                    {
                        if ( equali(szKey, "CORPSE_MODEL") )
                        {
                            copy( eCorpse[CORPSE_MODEL], charsmax(eCorpse[CORPSE_MODEL]), szValue)
                            if ( !g_bFileWasRead )
                                precache_model(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_MINS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eCorpse[CORPSE_MINS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eCorpse[CORPSE_MINS][1] = str_to_float(szKey)
                            eCorpse[CORPSE_MINS][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_MAXS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eCorpse[CORPSE_MAXS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eCorpse[CORPSE_MAXS][1] = str_to_float(szKey)
                            eCorpse[CORPSE_MAXS][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_FLAGS") )
                        {
                            eCorpse[CORPSE_FLAGS] = read_flags(szValue)
                            eCorpse[CORPSE_FLAGS] &= 127
                        }
                        else if ( equali(szKey, "CORPSE_TEAM") )
                        {
                            eCorpse[CORPSE_TEAM] = str_to_num(szValue)
                            eCorpse[CORPSE_TEAM] = clamp(eCorpse[CORPSE_TEAM], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "CORPSE_SPAWN_CHANCE") )
                        {
                            eCorpse[CORPSE_SPAWN_CHANCE] = str_to_float(szValue)
                            eCorpse[CORPSE_SPAWN_CHANCE] = floatclamp(eCorpse[CORPSE_SPAWN_CHANCE], 0.0, 1.0)
                        }
                        else if ( equali(szKey, "CORPSE_SEQUENCE") )
                        {
                            eCorpse[CORPSE_SEQUENCE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_FRAME") )
                        {
                            eCorpse[CORPSE_FRAME] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_FRAMERATE") )
                        {
                            eCorpse[CORPSE_FRAMERATE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CORPSE_RADIUS") )
                        {
                            eCorpse[CORPSE_RADIUS] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_RADIUS] < 0.0 ) eCorpse[CORPSE_RADIUS] = 200.0
                        }
                        else if ( equali(szKey, "CORPSE_SPEED") )
                        {
                            eCorpse[CORPSE_SPEED] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_SPEED] < 0.0 ) eCorpse[CORPSE_SPEED] = 1.0
                        }
                        else if ( equali(szKey, "CORPSE_GRAVITY") )
                        {
                            eCorpse[CORPSE_GRAVITY] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_GRAVITY] < 0.0 ) eCorpse[CORPSE_GRAVITY] = 1.0
                        }
                        else if ( equali(szKey, "CORPSE_POISON_MIN") )
                        {
                            eCorpse[CORPSE_POISON_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_MIN] < 0.0 ) eCorpse[CORPSE_POISON_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_POISON_MAX") )
                        {
                            eCorpse[CORPSE_POISON_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_MAX] < eCorpse[CORPSE_POISON_MIN] ) eCorpse[CORPSE_POISON_MAX] = eCorpse[CORPSE_POISON_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_POISON_DELAY_MIN") )
                        {
                            eCorpse[CORPSE_POISON_DELAY_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_DELAY_MIN] < 0.0 ) eCorpse[CORPSE_POISON_DELAY_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_POISON_DELAY_MAX") )
                        {
                            eCorpse[CORPSE_POISON_DELAY_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_DELAY_MAX] < eCorpse[CORPSE_POISON_DELAY_MIN] ) eCorpse[CORPSE_POISON_DELAY_MAX] = eCorpse[CORPSE_POISON_DELAY_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_POISON_DURATION_MIN") )
                        {
                            eCorpse[CORPSE_POISON_DURATION_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_DURATION_MIN] < 0.0 ) eCorpse[CORPSE_POISON_DURATION_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_POISON_DURATION_MAX") )
                        {
                            eCorpse[CORPSE_POISON_DURATION_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_POISON_DURATION_MAX] < eCorpse[CORPSE_POISON_DURATION_MIN] ) eCorpse[CORPSE_POISON_DURATION_MAX] = eCorpse[CORPSE_POISON_DURATION_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_MIN") )
                        {
                            eCorpse[CORPSE_REGEN_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_MIN] < 0.0 ) eCorpse[CORPSE_REGEN_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_MAX") )
                        {
                            eCorpse[CORPSE_REGEN_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_MAX] < eCorpse[CORPSE_REGEN_MIN] ) eCorpse[CORPSE_REGEN_MAX] = eCorpse[CORPSE_REGEN_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_DELAY_MIN") )
                        {
                            eCorpse[CORPSE_REGEN_DELAY_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_DELAY_MIN] < 0.0 ) eCorpse[CORPSE_REGEN_DELAY_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_DELAY_MAX") )
                        {
                            eCorpse[CORPSE_REGEN_DELAY_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_DELAY_MAX] < eCorpse[CORPSE_REGEN_DELAY_MIN] ) eCorpse[CORPSE_REGEN_DELAY_MAX] = eCorpse[CORPSE_REGEN_DELAY_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_DURATION_MIN") )
                        {
                            eCorpse[CORPSE_REGEN_DURATION_MIN] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_DURATION_MIN] < 0.0 ) eCorpse[CORPSE_REGEN_DURATION_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CORPSE_REGEN_DURATION_MAX") )
                        {
                            eCorpse[CORPSE_REGEN_DURATION_MAX] = str_to_float(szValue)
                            if ( eCorpse[CORPSE_REGEN_DURATION_MAX] < eCorpse[CORPSE_REGEN_DURATION_MIN] ) eCorpse[CORPSE_REGEN_DURATION_MAX] = eCorpse[CORPSE_REGEN_DURATION_MIN]
                        }
                        else if ( equali(szKey, "CORPSE_WEAPON_LIST") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            trim(szKey)
                            trim(szValue)

                            while( szKey[0] )
                            {
                                iWeapon = str_to_num(szKey)

                                if ( iWeapon >= 1 && iWeapon <= 30
                                && eCorpse[CORPSE_WEAPON_LIST_COUNT] < sizeof(eCorpse[CORPSE_WEAPON_LIST]) )
                                    eCorpse[CORPSE_WEAPON_LIST][eCorpse[CORPSE_WEAPON_LIST_COUNT] ++] = iWeapon

                                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                                trim(szKey)
                            }
                        }
                    }
                }
            }
        }
    }

    if ( g_iCorpseConfig )
        ArrayPushArray(g_aCorpseConfig, eCorpse)
    else
        set_fail_state("No Corpses were found in the configuration file.")

    if ( g_bFileWasRead )
    {
        if ( g_eSettings[SETTING_CORPSE_ACTION] )
        {
            if ( !task_exists(TASK_ACTION) )
                set_task(g_eSettings[SETTING_GHOST_FREQ], "corpseTask", TASK_ACTION, .flags = "b")
        }
        else
            remove_task(TASK_ACTION)

        if ( g_eSettings[SETTING_CORPSE_EFFECT] )
        {
            if ( !task_exists(TASK_EFFECT) )
                set_task(g_eSettings[SETTING_EFFECT_FREQ], "corpseEffect", TASK_EFFECT, .flags = "b")
        }
        else
            remove_task(TASK_EFFECT)
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS]    = get_user_flags(id)
    g_ePlayerData[id][PDATA_OFFSET]         = g_eSettings[SETTING_OFFSET_BASE]
}

public corpseInit()
{
    if ( g_eSettings[SETTING_CORPSE_LOAD] )
        loadData()
}

public corpseMenu(id, iType)
{
    new szTitle[64],
        iMenu

    formatex(szTitle, charsmax(szTitle), "%L", id, "CORPSE_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(iMenu);      format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_CREATE"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_REMOVE"); }
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_SHOW"); }
        case MENU_POISON: { menuPoison(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_POISON"); }
        case MENU_REGEN:  { menuRegen(id, iMenu);   format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_REGEN"); }
        case MENU_WEAPON: { menuWeapon(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_WEAPON"); }
        case MENU_TEAM:   { menuTeam(id, iMenu);    format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_TEAM"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CORPSE_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szTitle)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_POISON")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_REGEN")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_WEAPON")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_TEAM")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCorpse >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_LIMIT", MAX_ENT)
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_CREATE)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_REMOVE)
                corpseMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_SHOW:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_SHOW)
            }
        }
        case ROOT_POISON:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_POISON)
            }
        }
        case ROOT_REGEN:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_REGEN)
            }
        }
        case ROOT_WEAPON:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_WEAPON)
            }
        }
        case ROOT_TEAM :
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_TEAM)
            }
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new eCorpse[CORPSE],
        szItem[64]

    for ( new i = 0; i < g_iCorpseConfig; i ++ )
    {
        ArrayGetArray(g_aCorpseConfig, i, eCorpse)

        copy(szItem, charsmax(szItem), eCorpse[CORPSE_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( item == MENU_EXIT
    || !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    corpseCreate(id, item)
    corpseSound(id, SOUND_MENU_NAV)
    corpseMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_REMOVE_CURRENT", eCorpse[CORPSE_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerRemove(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            corpseKill(eCorpse[CORPSE_ID])
            corpseRemove(g_ePlayerData[id][PDATA_CORPSE_MENU])

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_REMOVE_CURRENT", eCorpse[CORPSE_NAME])
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0

            corpseSound(id, g_iCorpse > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            corpseMenu(id, g_iCorpse > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iCorpse )
            {
                ArrayGetArray(g_aCorpse, 0, eCorpse)

                corpseKill(eCorpse[CORPSE_ID])
                corpseRemove(0)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_ROOT)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

stock saveData(id)
{
    new eCorpse[CORPSE],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_CorpseSpawn.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eCorpse[CORPSE_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", eCorpse[CORPSE_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "team = %d^n", eCorpse[CORPSE_TEAM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eCorpse[CORPSE_ORIGIN][0], eCorpse[CORPSE_ORIGIN][1], eCorpse[CORPSE_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n^n",
        eCorpse[CORPSE_ANGLES][0], eCorpse[CORPSE_ANGLES][1], eCorpse[CORPSE_ANGLES][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SAVE", szFile)
    fclose(iFile)

    return PLUGIN_HANDLED
}

stock loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iFlags, iTeam, iItem,
        eCorpse[CORPSE], iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_CorpseSpawn.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                corpseCreate(0, iItem)
                ArrayGetArray(g_aCorpse, iCount, eCorpse)

                xs_vec_copy(fOrigin, eCorpse[CORPSE_ORIGIN])
                xs_vec_copy(fAngles, eCorpse[CORPSE_ANGLES])
                set_pev(eCorpse[CORPSE_ID], pev_origin, fOrigin)
                set_pev(eCorpse[CORPSE_ID], pev_angles, fAngles)
                eCorpse[CORPSE_FLAGS] = iFlags
                eCorpse[CORPSE_TEAM] = iTeam

                corpseSetBox(eCorpse)
                corpseSetAnim(eCorpse)
                corpseSetSolid(eCorpse)
                ArraySetArray(g_aCorpse, iCount, eCorpse)
            }

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 'i':
                {
                    iItem = str_to_num(szValue)
                }
                case 'f':
                {
                    iFlags = str_to_num(szValue)
                }
                case 't':
                {
                    iTeam = str_to_num(szValue)
                }
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'a':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[1] = str_to_float(szKey)
                    fAngles[2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        corpseCreate(0, iItem)
        ArrayGetArray(g_aCorpse, iCount, eCorpse)

        xs_vec_copy(fOrigin, eCorpse[CORPSE_ORIGIN])
        xs_vec_copy(fAngles, eCorpse[CORPSE_ANGLES])
        set_pev(eCorpse[CORPSE_ID], pev_origin, fOrigin)
        set_pev(eCorpse[CORPSE_ID], pev_angles, fAngles)
        eCorpse[CORPSE_FLAGS] = iFlags
        eCorpse[CORPSE_TEAM] = iTeam

        corpseSetBox(eCorpse)
        corpseSetAnim(eCorpse)
        corpseSetSolid(eCorpse)
        ArraySetArray(g_aCorpse, iCount, eCorpse)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public menuShow(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_SHOW_CURRENT",
    g_szShowColor[eCorpse[CORPSE_SHOW]], eCorpse[CORPSE_NAME], id, g_szShow[eCorpse[CORPSE_SHOW]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_SHOW_ALL_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_SHOW_ALL_HIDE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_SHOW_ALL_DEFAULT")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerShow(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case SHOW_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_CURRENT:
        {
            if ( ++ eCorpse[CORPSE_SHOW] > SHOW_FORCE_HIDE )
                eCorpse[CORPSE_SHOW] = SHOW_DEFAULT

            if ( eCorpse[CORPSE_SHOW] == SHOW_FORCE_SHOW )
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
            else if ( eCorpse[CORPSE_SHOW] == SHOW_FORCE_HIDE )
                eCorpse[CORPSE_FLAGS] &= ~(FLAG_SHOW | FLAG_POISON)

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SHOW_CURRENT",
            eCorpse[CORPSE_NAME], id, g_szShowChat[eCorpse[CORPSE_SHOW]])
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                set_pev(eCorpse[CORPSE_ID], pev_solid, eCorpse[CORPSE_FLAGS] & FLAG_SHOW ? SOLID_BBOX : SOLID_NOT)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_SHOW:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_SHOW] = SHOW_FORCE_SHOW
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW

                if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                    set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_SHOW_ALL_SHOWN")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_HIDE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_SHOW] = SHOW_FORCE_HIDE
                eCorpse[CORPSE_FLAGS] &= ~(FLAG_SHOW | FLAG_POISON)

                if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                    set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_NOT)

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_SHOW_ALL_HIDDEN")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_SHOW] = SHOW_DEFAULT
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_SHOW_ALL_DEFAULT")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuPoison(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_POISON_CURRENT",
    eCorpse[CORPSE_FLAGS] & FLAG_POISON ? "\y" : "\r", eCorpse[CORPSE_NAME], id,
    eCorpse[CORPSE_FLAGS] & FLAG_POISON ? "CORPSE_ACTIVE" : "CORPSE_INACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_ACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_INACTIVE")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerPoison(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case POISON_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_POISON)
        }
        case POISON_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_POISON)
        }
        case POISON_CURRENT:
        {
            eCorpse[CORPSE_FLAGS] ^= FLAG_POISON

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_POISON_CURRENT",
            eCorpse[CORPSE_NAME], id, eCorpse[CORPSE_FLAGS] & FLAG_POISON ? "CORPSE_CHAT_ACTIVATED" : "CORPSE_CHAT_DEACTIVATED")
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_POISON)
        }
        case POISON_ALL_ACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] |= FLAG_POISON

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_POISON_ALL_ACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_POISON)
        }
        case POISON_ALL_INACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] &= ~FLAG_POISON

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_POISON_ALL_INACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_POISON)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRegen(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_REGEN_CURRENT",
    eCorpse[CORPSE_FLAGS] & FLAG_REGEN ? "\y" : "\r", eCorpse[CORPSE_NAME], id,
    eCorpse[CORPSE_FLAGS] & FLAG_REGEN ? "CORPSE_ACTIVE" : "CORPSE_INACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_ACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_INACTIVE")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerRegen(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case REGEN_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_REGEN)
        }
        case REGEN_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_REGEN)
        }
        case REGEN_CURRENT:
        {
            eCorpse[CORPSE_FLAGS] ^= FLAG_REGEN

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_REGEN_CURRENT",
            eCorpse[CORPSE_NAME], id, eCorpse[CORPSE_FLAGS] & FLAG_REGEN ? "CORPSE_CHAT_ACTIVATED" : "CORPSE_CHAT_DEACTIVATED")
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_REGEN)
        }
        case REGEN_ALL_ACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] |= FLAG_REGEN

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_REGEN_ALL_ACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_REGEN)
        }
        case REGEN_ALL_INACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] &= ~FLAG_REGEN

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_REGEN_ALL_INACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_REGEN)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuWeapon(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_WEAPON_CURRENT",
    eCorpse[CORPSE_FLAGS] & FLAG_WEAPON ? "\y" : "\r", eCorpse[CORPSE_NAME], id,
    eCorpse[CORPSE_FLAGS] & FLAG_WEAPON ? "CORPSE_ACTIVE" : "CORPSE_INACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_ACTIVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ALL_INACTIVE")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerWeapon(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case WEAPON_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_WEAPON)
        }
        case WEAPON_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_WEAPON)
        }
        case WEAPON_CURRENT:
        {
            eCorpse[CORPSE_FLAGS] ^= FLAG_WEAPON

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_WEAPON_CURRENT",
            eCorpse[CORPSE_NAME], id, eCorpse[CORPSE_FLAGS] & FLAG_WEAPON ? "CORPSE_CHAT_ACTIVATED" : "CORPSE_CHAT_DEACTIVATED")
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_WEAPON)
        }
        case WEAPON_ALL_ACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] |= FLAG_WEAPON

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_WEAPON_ALL_ACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_WEAPON)
        }
        case WEAPON_ALL_INACTIVE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] &= ~FLAG_WEAPON

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_WEAPON_ALL_INACTIVE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_WEAPON)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuTeam(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_TEAM_CURRENT",
    eCorpse[CORPSE_NAME], id, g_szTeam[eCorpse[CORPSE_TEAM]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_TEAM_ALL_NONE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_TEAM_ALL_T")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_TEAM_ALL_CT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_TEAM_ALL_BOTH")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
    eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
}

public menuHandlerTeam(id, menu, item)
{
    new eCorpse[CORPSE]

    ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
    eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

    switch( item )
    {
        case TEAM_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] >= g_iCorpse - 1 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] ++

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CORPSE_MENU] = g_iCorpse - 1
            else
                g_ePlayerData[id][PDATA_CORPSE_MENU] --

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_CURRENT:
        {
            if ( ++ eCorpse[CORPSE_TEAM] > TEAM_BOTH )
                eCorpse[CORPSE_TEAM] = TEAM_NONE

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_TEAM_CURRENT",
            eCorpse[CORPSE_NAME], id, g_szTeamChat[eCorpse[CORPSE_TEAM]])
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_NONE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_TEAM] = TEAM_NONE
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_TEAM_ALL_NONE")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_T:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_TEAM] = TEAM_T
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_TEAM_ALL_T")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_CT:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_TEAM] = TEAM_CT
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_TEAM_ALL_CT")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_BOTH:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_TEAM] = TEAM_BOTH
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(0, 0, "%L %L", 0, "CORPSE_CHAT_TAG", 0, "CORPSE_CHAT_TEAM_ALL_BOTH")

            corpseSound(0, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_TEAM)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64],
        eCorpse[CORPSE]

    corpseFind(g_ePlayerData[id][PDATA_CORPSE_GHOST], eCorpse)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROTATE_RIGHT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROTATE_LEFT")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROTATE_GROUND",
    id, eCorpse[CORPSE_FLAGS] & FLAG_GROUND ? "CORPSE_ON" : "CORPSE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eCorpse[CORPSE],
        iItem

    iItem = corpseFind(g_ePlayerData[id][PDATA_CORPSE_GHOST], eCorpse)

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            pev(eCorpse[CORPSE_ID], pev_angles, eCorpse[CORPSE_ANGLES])
            eCorpse[CORPSE_ANGLES][1] -= 22.5
            if ( eCorpse[CORPSE_ANGLES][1] < -180.0 ) eCorpse[CORPSE_ANGLES][1] += 360.0

            set_pev(eCorpse[CORPSE_ID], pev_angles, eCorpse[CORPSE_ANGLES])
            ArraySetArray(g_aCorpse, iItem, eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_ROTATE)
        }
        case ROTATE_LEFT:
        {
            pev(eCorpse[CORPSE_ID], pev_angles, eCorpse[CORPSE_ANGLES])
            eCorpse[CORPSE_ANGLES][1] += 22.5
            if ( eCorpse[CORPSE_ANGLES][1] > 180.0 ) eCorpse[CORPSE_ANGLES][1] -= 360.0

            set_pev(eCorpse[CORPSE_ID], pev_angles, eCorpse[CORPSE_ANGLES])
            ArraySetArray(g_aCorpse, iItem, eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_ROTATE)
        }
        case ROTATE_GROUND:
        {
            eCorpse[CORPSE_FLAGS] ^= FLAG_GROUND
            ArraySetArray(g_aCorpse, iItem, eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            if ( iItem != -1 )
            {
                corpseTrace(eCorpse, id)

                g_ePlayerData[id][PDATA_CORPSE_GHOST] = 0
                g_ePlayerData[id][PDATA_CORPSE_ACTION] = false

                pev(eCorpse[CORPSE_ID], pev_origin, eCorpse[CORPSE_ORIGIN])
                pev(eCorpse[CORPSE_ID], pev_angles, eCorpse[CORPSE_ANGLES])
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW

                corpseNoClip(id, false)
                corpseSetAnim(eCorpse)
                corpseSetSolid(eCorpse)
                ArraySetArray(g_aCorpse, iItem, eCorpse)

                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_CREATE_NEW", eCorpse[CORPSE_NAME])
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_ROOT)
            }
        }
        default:
        {
            corpseNoClip(id, false)
            corpseKill(eCorpse[CORPSE_ID])
            corpseRemove(iItem)
            g_ePlayerData[id][PDATA_CORPSE_GHOST] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public corpseTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eCorpse[CORPSE], iEnt

    get_players(iPlayers, iNum, "ach")
    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iEnt = g_ePlayerData[id][PDATA_CORPSE_GHOST]
        if ( !iEnt || corpseFind(iEnt, eCorpse) == -1 )
            continue

        corpseTrace(eCorpse, id)
    }
}

public corpseEffect()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        Float:fOrigin[3]

    get_players(iPlayers, iNum, "ah")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        pev(id, pev_origin, fOrigin)

        effectDamage(id, fOrigin)
    }
}

stock corpseCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCorpse[CORPSE]
    ArrayGetArray(g_aCorpseConfig, iItem, eCorpse)

    eCorpse[CORPSE_ID] = iEnt
    eCorpse[CORPSE_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CORPSE_GHOST] = eCorpse[CORPSE_ID]
        g_ePlayerData[id][PDATA_CORPSE_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

        corpseNoClip(id, true)
    }

    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(eCorpse[CORPSE_ID], pev_sequence, eCorpse[CORPSE_SEQUENCE])
    engfunc(EngFunc_SetModel, iEnt, eCorpse[CORPSE_MODEL])

    ArrayPushArray(g_aCorpse, eCorpse)
    g_iCorpse ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

stock corpseRemove(iItem)
{
    ArrayDeleteItem(g_aCorpse, iItem)
    g_iCorpse --
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isCorpse(iEnt)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new eCorpse[CORPSE],
        bool:bHidden

    corpseFind(iEnt, eCorpse)
    bHidden = !(eCorpse[CORPSE_FLAGS] & FLAG_SHOW)

    if ( !g_ePlayerData[iHost][PDATA_CORPSE_ACTION] )
    {
        if ( bHidden )
            set_es(es, ES_Effects, EF_NODRAW)
    }
    else if ( eCorpse[CORPSE_FLAGS] & FLAG_SELECT )
    {
        set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_SELECT])
        set_es(es, ES_RenderAmt, 32)
        set_es(es, ES_RenderFx, kRenderFxGlowShell)

        if ( bHidden )
            set_es(es, ES_RenderMode, kRenderTransAlpha)
    }
    else if ( bHidden )
    {
        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isCorpse(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCorpse[CORPSE], iButton, Float:fCurrentTime, iLast
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST] )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    for ( new i = 0; i < g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT]; i ++ )
    {
        if ( g_ePlayerData[id][PDATA_CORPSE_POISON_END][i]
        && g_ePlayerData[id][PDATA_CORPSE_POISON_END][i] > fCurrentTime )
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][i]
            && fCurrentTime >= g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][i] )
            {
                corpseFind(g_ePlayerData[id][PDATA_CORPSE_POISON][i], eCorpse)

                fakedamage(id, "weapon_knife",
                random_float(eCorpse[CORPSE_POISON_MIN], eCorpse[CORPSE_POISON_MAX]),
                DMG_SLASH)

                g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][i] += random_float(eCorpse[CORPSE_POISON_DELAY_MIN], eCorpse[CORPSE_POISON_DELAY_MAX])
                poisonIcon(id, DMG_POISON)
            }
        }
        else if ( g_ePlayerData[id][PDATA_CORPSE_POISON_END][i] )
        {
            iLast = g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT] - 1

            g_ePlayerData[id][PDATA_CORPSE_POISON][i]       = g_ePlayerData[id][PDATA_CORPSE_POISON][iLast]
            g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][i]  = g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][iLast]
            g_ePlayerData[id][PDATA_CORPSE_POISON_END][i]   = g_ePlayerData[id][PDATA_CORPSE_POISON_END][iLast]
            g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT] --
            i --
        }
    }

    for ( new i = 0; i < g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT]; i ++ )
    {
        if ( g_ePlayerData[id][PDATA_CORPSE_REGEN_END][i]
        && g_ePlayerData[id][PDATA_CORPSE_REGEN_END][i] > fCurrentTime )
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][i]
            && fCurrentTime >= g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][i] )
            {
                new Float:fHealth
                corpseFind(g_ePlayerData[id][PDATA_CORPSE_POISON][i], eCorpse)

                pev(id, pev_health, fHealth)
                set_pev(id, pev_health, fHealth + random_float(eCorpse[CORPSE_REGEN_MIN], eCorpse[CORPSE_REGEN_MAX]))

                g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][i] += random_float(eCorpse[CORPSE_REGEN_DELAY_MIN], eCorpse[CORPSE_REGEN_DELAY_MAX])
            }
        }
        else if ( g_ePlayerData[id][PDATA_CORPSE_REGEN_END][i] )
        {
            iLast = g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT] - 1

            g_ePlayerData[id][PDATA_CORPSE_REGEN][i]       = g_ePlayerData[id][PDATA_CORPSE_REGEN][iLast]
            g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][i]  = g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][iLast]
            g_ePlayerData[id][PDATA_CORPSE_REGEN_END][i]   = g_ePlayerData[id][PDATA_CORPSE_REGEN_END][iLast]
            g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT] --
            i --
        }
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST] )
    {
        new eCorpse[CORPSE], iItem

        if ( (iItem = corpseFind(g_ePlayerData[id][PDATA_CORPSE_GHOST], eCorpse)) != -1 )
        {
            corpseKill(g_ePlayerData[id][PDATA_CORPSE_GHOST])
            corpseRemove(iItem)
            g_ePlayerData[id][PDATA_CORPSE_GHOST] = 0
        }

        corpseNoClip(id, false)
    }

    corpseReset(id)
    return HAM_IGNORED
}

public fwdResetMaxSpeedPlayer(id)
{
    if ( !is_user_alive(id)
    || g_ePlayerData[id][PDATA_CORPSE_SPEED_COUNT] == 0 )
        return HAM_IGNORED

    new eCorpse[CORPSE],
        Float:fSpeed

    fSpeed = g_ePlayerData[id][PDATA_BASE_SPEED]

    for ( new i = 0; i < g_ePlayerData[id][PDATA_CORPSE_SPEED_COUNT]; i ++ )
    {
        corpseFind(g_ePlayerData[id][PDATA_CORPSE_SPEED][i], eCorpse)
        fSpeed *= eCorpse[CORPSE_SPEED]
    }

    set_pev(id, pev_maxspeed, fSpeed)
    return HAM_IGNORED
}

stock bool:corpseTrace(eCorpse[CORPSE], id)
{
    new Float:fVec1[3]

    pev(id, pev_origin, eCorpse[CORPSE_ORIGIN])
    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eCorpse[CORPSE_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eCorpse[CORPSE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eCorpse[CORPSE_ORIGIN])

    corpseSetBox(eCorpse)
    corpseSetOffset(eCorpse)
    set_pev(eCorpse[CORPSE_ID], pev_origin, eCorpse[CORPSE_ORIGIN])
}

stock corpseSetBox(eCorpse[CORPSE])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    engfunc(EngFunc_AngleVectors, eCorpse[CORPSE_ANGLES], fForward, fRight, fUp)
    xs_vec_copy(eCorpse[CORPSE_MINS], fMins)
    xs_vec_copy(eCorpse[CORPSE_MAXS], fMaxs)

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, eCorpse[CORPSE_MINS])
    xs_vec_copy(fMaxs, eCorpse[CORPSE_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock corpseSetOffset(eCorpse[CORPSE])
{
    new Float:fGaps[6], Float:fVec1[3],
        Float:fCurrentGap

    fGaps[0] = -eCorpse[CORPSE_MINS][0]
    fGaps[1] = eCorpse[CORPSE_MAXS][0]
    fGaps[2] = -eCorpse[CORPSE_MINS][1]
    fGaps[3] = eCorpse[CORPSE_MAXS][1]
    fGaps[4] = -eCorpse[CORPSE_MINS][2]
    fGaps[5] = eCorpse[CORPSE_MAXS][2]

    if ( eCorpse[CORPSE_FLAGS] & FLAG_GROUND )
    {
        xs_vec_sub(eCorpse[CORPSE_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
        engfunc(EngFunc_TraceLine, eCorpse[CORPSE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCorpse[CORPSE_ID], 0)
        get_tr2(0, TR_vecEndPos, eCorpse[CORPSE_ORIGIN])
    }

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eCorpse[CORPSE_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eCorpse[CORPSE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCorpse[CORPSE_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eCorpse[CORPSE_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(eCorpse[CORPSE_ORIGIN], fVec1, eCorpse[CORPSE_ORIGIN])
        }
    }
}

stock corpseSetSolid(eCorpse[CORPSE])
{
    if ( g_eSettings[SETTING_CORPSE_SOLID] && eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
    {
        new Float:fMins[3],
            Float:fMaxs[3]

        set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
        set_pev(eCorpse[CORPSE_ID], pev_movetype, MOVETYPE_NONE)

        xs_vec_copy(eCorpse[CORPSE_MINS], fMins)
        xs_vec_copy(eCorpse[CORPSE_MAXS], fMaxs)
        engfunc(EngFunc_SetSize, eCorpse[CORPSE_ID], fMins, fMaxs)
        set_rendering(eCorpse[CORPSE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
    }
}

stock corpseSetAnim(eCorpse[CORPSE])
{
    if ( g_eSettings[SETTING_CORPSE_ANIM] && eCorpse[CORPSE_FLAGS] & FLAG_ANIM )
    {
        set_pev(eCorpse[CORPSE_ID], pev_frame, eCorpse[CORPSE_FRAME])
        set_pev(eCorpse[CORPSE_ID], pev_framerate, eCorpse[CORPSE_FRAMERATE])
        set_pev(eCorpse[CORPSE_ID], pev_animtime, get_gametime())
    }
}

stock corpseNoClip(id, bool:bSet)
{
    if ( g_eSettings[SETTING_CORPSE_NOCLIP] )
        set_pev(id, pev_movetype, bSet ? MOVETYPE_NOCLIP : MOVETYPE_WALK)
}

stock effectDamage(id, Float:fOrigin[3])
{
    new eCorpse[CORPSE],
        Float:fDist, Float:fMin, Float:fGravity

    g_ePlayerData[id][PDATA_CORPSE_SPEED_COUNT] = 0
    g_ePlayerData[id][PDATA_CORPSE_GRAVITY_COUNT] = 0
    g_ePlayerData[id][PDATA_CORPSE_CLOSEST] = -1
    fMin = FLOAT_MAX

    pev(id, pev_maxspeed, g_ePlayerData[id][PDATA_BASE_SPEED])

    if ( !g_ePlayerData[id][PDATA_BASE_GRAVITY] )
        pev(id, pev_gravity, g_ePlayerData[id][PDATA_BASE_GRAVITY])

    fGravity = g_ePlayerData[id][PDATA_BASE_GRAVITY]

    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)

        if ( !(eCorpse[CORPSE_FLAGS] & FLAG_SHOW)
        || !(cs_get_user_team(id) & CsTeams:eCorpse[CORPSE_TEAM])
        || (fDist = xs_vec_distance(fOrigin, eCorpse[CORPSE_ORIGIN])) > eCorpse[CORPSE_RADIUS] )
            continue

        if ( eCorpse[CORPSE_FLAGS] & FLAG_SPEED )
            g_ePlayerData[id][PDATA_CORPSE_SPEED][g_ePlayerData[id][PDATA_CORPSE_SPEED_COUNT] ++] = eCorpse[CORPSE_ID]

        if ( eCorpse[CORPSE_FLAGS] & FLAG_GRAVITY )
        {
            fGravity *= eCorpse[CORPSE_GRAVITY]
            g_ePlayerData[id][PDATA_CORPSE_GRAVITY_COUNT] ++
        }

        if ( eCorpse[CORPSE_FLAGS] & FLAG_POISON
        && !isPoisonExist(id, eCorpse[CORPSE_ID]) )
        {
            g_ePlayerData[id][PDATA_CORPSE_POISON][g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT]] = eCorpse[CORPSE_ID]
            g_ePlayerData[id][PDATA_CORPSE_POISON_NEXT][g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT]] = get_gametime()
            g_ePlayerData[id][PDATA_CORPSE_POISON_END][g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT]] = get_gametime() + random_float(eCorpse[CORPSE_POISON_DURATION_MIN], eCorpse[CORPSE_POISON_DURATION_MAX])
            g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT] ++
        }

        if ( eCorpse[CORPSE_FLAGS] & FLAG_REGEN
        && !isRegenExist(id, eCorpse[CORPSE_ID]) )
        {
            g_ePlayerData[id][PDATA_CORPSE_REGEN][g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT]] = eCorpse[CORPSE_ID]
            g_ePlayerData[id][PDATA_CORPSE_REGEN_NEXT][g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT]] = get_gametime()
            g_ePlayerData[id][PDATA_CORPSE_REGEN_END][g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT]] = get_gametime() + random_float(eCorpse[CORPSE_REGEN_DURATION_MIN], eCorpse[CORPSE_REGEN_DURATION_MAX])
            g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT] ++
        }

        if ( fDist < fMin )
        {
            fMin = fDist
            g_ePlayerData[id][PDATA_CORPSE_CLOSEST] = eCorpse[CORPSE_ID]
        }
    }

    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
    set_pev(id, pev_gravity, fGravity)

    if ( corpseFind(g_ePlayerData[id][PDATA_CORPSE_CLOSEST], eCorpse) != -1
    && eCorpse[CORPSE_FLAGS] & FLAG_WEAPON )
        effectWeapon(id, eCorpse)
}

stock effectWeapon(id, eCorpse[CORPSE])
{
    new iWeapons[32], szWeapon[32], iNum
    get_user_weapons(id, iWeapons, iNum)

    for ( new i = 0; i < eCorpse[CORPSE_WEAPON_LIST_COUNT]; i ++ )
    {
        for ( new j = 0; j < iNum; j ++ )
        {
            if ( iWeapons[j] == eCorpse[CORPSE_WEAPON_LIST][i] )
            {
                if ( iWeapons[j] != get_user_weapon(id) )
                {
                    get_weaponname(iWeapons[j], szWeapon, charsmax(szWeapon))
                    client_cmd(id, szWeapon)
                }

                return
            }
        }
    }
}

stock poisonIcon(id, iType)
{
    message_begin(MSG_ONE, g_iDamage, .player = id)
    write_byte(0)
    write_byte(0)
    write_long(iType)
    write_coord(0)
    write_coord(0)
    write_coord(0)
    message_end()
}

stock corpseReset(id)
{
    g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT] = 0
    g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT] = 0
}

stock bool:isPoisonExist(id, iCorpse)
{
    for ( new i = 0; i < g_ePlayerData[id][PDATA_CORPSE_POISON_COUNT]; i ++ )
        if ( g_ePlayerData[id][PDATA_CORPSE_POISON][i] == iCorpse )
            return true

    return false
}

stock bool:isRegenExist(id, iCorpse)
{
    for ( new i = 0; i < g_ePlayerData[id][PDATA_CORPSE_REGEN_COUNT]; i ++ )
    {
        if ( g_ePlayerData[id][PDATA_CORPSE_REGEN][i] == iCorpse )
            return true
    }

    return false
}

stock corpseSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock bool:isCorpse(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    return bool:equal(g_szCN, szEnt)
}

stock corpseKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock corpseFind(iEnt, eCorpse[CORPSE])
{
    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)
        if ( eCorpse[CORPSE_ID] == iEnt )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}


