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
*       v1.3: Added interactive messages and ambient sounds per corpse, config improvements.
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

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT             32
#define CORPSE_KEY          556677
#define CORPSE_ARRAY_ITEM   pev_iuser1

new const PLUGIN_VERSION[]          = "1.3"
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
    DTYPE_FLOAT,
    DTYPE_FLOAT_RANGE,
    DTYPE_INT,
    DTYPE_INT_RANGE,
    DTYPE_BOOL,
    DTYPE_FLAGS,
    DTYPE_VECTOR,
    DTYPE_VECTOR_FLOAT,
    DTYPE_ARRAY,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_SPRITE
}

enum
{
    FLAG_SOLID              = (1 << 0),
    FLAG_ANIM               = (1 << 1),
    FLAG_MESSAGE            = (1 << 2),
    FLAG_SOUND              = (1 << 3),

    FLAG_SHOW               = (1 << 4),
    FLAG_GHOST              = (1 << 5),
    FLAG_GROUND             = (1 << 6),
    FLAG_SELECT             = (1 << 7)
}

enum
{
    SHOW_DEFAULT,
    SHOW_FORCE_SHOW,
    SHOW_FORCE_HIDE
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,

    SETTING_DEFAULT_SEQUENCE,
    Float:SETTING_DEFAULT_FRAMERATE,
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Array:SETTING_DEFAULT_MESSAGE,
    SETTING_DEFAULT_MESSAGE_TIMEOUT[2],
    SETTING_DEFAULT_MESSAGE_COUNT,
    Array:SETTING_DEFAULT_SOUND,
    Float:SETTING_DEFAULT_SOUND_COOLDOWN[2],
    Float:SETTING_DEFAULT_SOUND_DISTANCE,
    SETTING_DEFAULT_SOUND_COUNT,

    bool:SETTING_CORPSE_LOAD,
    Float:SETTING_CORPSE_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
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
    CORPSE_NAME[MAX_VALUE_LENGTH],
    CORPSE_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:CORPSE_ORIGIN[3],
    Float:CORPSE_ANGLES[3],
    Float:CORPSE_MINS[3],
    Float:CORPSE_MAXS[3],

    CORPSE_SEQUENCE,
    Float:CORPSE_FRAMERATE,
    Float:CORPSE_SPAWN_CHANCE,
    Array:CORPSE_MESSAGE,
    bool:CORPSE_MESSAGE_EXIST,
    CORPSE_MESSAGE_COUNT,
    Array:CORPSE_SOUND,
    Float:CORPSE_SOUND_COOLDOWN[2],
    bool:CORPSE_SOUND_EXIST,
    CORPSE_SOUND_COUNT,

    Float:CORPSE_NEXT_SOUND
}

enum _:PLAYER_DATA
{
    PDATA_CORPSE_GHOST,
    PDATA_CORPSE_MENU,
    bool:PDATA_CORPSE_ACTION,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET
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
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_SHOW,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
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
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
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
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szCN[] = "corpsespawn"

new Array:g_aCorpse,
    Array:g_aCorpseConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false,
    g_iCorpse, g_iCorpseConfig,
    g_iMaxPlayers

new g_szShow[][] = {"CORPSE_DEFAULT", "CORPSE_SHOWN", "CORPSE_HIDDEN"}
new g_szShowChat[][] = {"CORPSE_CHAT_DEFAULT", "CORPSE_CHAT_SHOWN", "CORPSE_CHAT_HIDDEN"}
new g_szShowColor[][] = {"\d", "\y", "\r"}

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
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "corpseTask", .flags = "b")

    corpseInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aCorpse = ArrayCreate(CORPSE)
    g_aCorpseConfig = ArrayCreate(CORPSE)
    g_eSettings[SETTING_DEFAULT_MESSAGE] = ArrayCreate(1024)
    g_eSettings[SETTING_DEFAULT_SOUND] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    ReadFile()
}

public plugin_end()
{
    new eCorpse[CORPSE]
    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)
        ArrayDestroy(eCorpse[CORPSE_MESSAGE])
        ArrayDestroy(eCorpse[CORPSE_SOUND])
    }

    for ( new i = 0; i < g_iCorpseConfig; i ++ )
    {
        ArrayGetArray(g_aCorpseConfig, i, eCorpse)
        ArrayDestroy(eCorpse[CORPSE_MESSAGE])
        ArrayDestroy(eCorpse[CORPSE_SOUND])
    }

    ArrayDestroy(g_aCorpse)
    ArrayDestroy(g_aCorpseConfig)
    ArrayDestroy(g_eSettings[SETTING_DEFAULT_MESSAGE])
    ArrayDestroy(g_eSettings[SETTING_DEFAULT_SOUND])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

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
            if ( eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
        }
        else
        {
            eCorpse[CORPSE_FLAGS] &= ~FLAG_SHOW
            if ( eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_NOT)
        }

        ArraySetArray(g_aCorpse, i, eCorpse)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    new eCorpse[CORPSE]

    if ( g_bFileWasRead )
    {
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)

        for ( new i = 0; i < g_iCorpse; i ++ )
        {
            ArrayGetArray(g_aCorpse, i, eCorpse)
            ArrayClear(eCorpse[CORPSE_MESSAGE])
            ArrayDestroy(eCorpse[CORPSE_SOUND])
        }

        for ( new i = 0; i < g_iCorpseConfig; i ++ )
        {
            ArrayGetArray(g_aCorpseConfig, i, eCorpse)
            ArrayClear(eCorpse[CORPSE_MESSAGE])
            ArrayDestroy(eCorpse[CORPSE_SOUND])
        }

        ArrayClear(g_eSettings[SETTING_DEFAULT_MESSAGE])
        ArrayClear(g_eSettings[SETTING_DEFAULT_SOUND])
        ArrayClear(g_aCorpseConfig)
        g_iCorpseConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/CorpseSpawn.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[1024],
        szKey[MAX_VALUE_LENGTH],
        szValue[1024],
        iSection = SECTION_NONE, iLine, iPos

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
                        eCorpse[CORPSE_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]

                        eCorpse[CORPSE_SEQUENCE]            = g_eSettings[SETTING_DEFAULT_SEQUENCE]
                        eCorpse[CORPSE_FRAMERATE]           = g_eSettings[SETTING_DEFAULT_FRAMERATE]
                        eCorpse[CORPSE_SPAWN_CHANCE]        = g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]

                        eCorpse[CORPSE_MESSAGE]             = ArrayClone(g_eSettings[SETTING_DEFAULT_MESSAGE])
                        eCorpse[CORPSE_MESSAGE_EXIST]       = false
                        eCorpse[CORPSE_MESSAGE_COUNT]       = g_eSettings[SETTING_DEFAULT_MESSAGE_COUNT]

                        eCorpse[CORPSE_SOUND]               = ArrayClone(g_eSettings[SETTING_DEFAULT_SOUND])
                        eCorpse[CORPSE_SOUND_EXIST]         = false
                        eCorpse[CORPSE_SOUND_COUNT]         = g_eSettings[SETTING_DEFAULT_SOUND_COUNT]
                        eCorpse[CORPSE_SOUND_COOLDOWN][0]   = g_eSettings[SETTING_DEFAULT_SOUND_COOLDOWN][0]
                        eCorpse[CORPSE_SOUND_COOLDOWN][1]   = g_eSettings[SETTING_DEFAULT_SOUND_COOLDOWN][1]

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
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

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
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FRAMERATE], charsmax(g_eSettings[SETTING_DEFAULT_FRAMERATE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SEQUENCE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SEQUENCE], charsmax(g_eSettings[SETTING_DEFAULT_SEQUENCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_MESSAGE") )
                        {
                            parseSetting(DTYPE_ARRAY, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MESSAGE], charsmax(g_eSettings[SETTING_DEFAULT_MESSAGE]))
                            g_eSettings[SETTING_DEFAULT_MESSAGE_COUNT] ++
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_MESSAGE_TIMEOUT") )
                            parseSetting(DTYPE_INT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MESSAGE_TIMEOUT], charsmax(g_eSettings[SETTING_DEFAULT_MESSAGE_TIMEOUT]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND") )
                        {
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND], charsmax(g_eSettings[SETTING_DEFAULT_SOUND]))
                            g_eSettings[SETTING_DEFAULT_SOUND_COUNT] ++
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_DISTANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_DISTANCE], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_DISTANCE]))
                        else if ( equali(szKey, "SETTING_CORPSE_LOAD") )
                            parseSetting(DTYPE_BOOL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CORPSE_LOAD], charsmax(g_eSettings[SETTING_CORPSE_LOAD]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_CORPSE_RANGE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CORPSE_RANGE], charsmax(g_eSettings[SETTING_CORPSE_RANGE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_FREQ], charsmax(g_eSettings[SETTING_OFFSET_FREQ]))
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_FREQ], charsmax(g_eSettings[SETTING_GHOST_FREQ]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]))
                        else if ( equali(szKey, "SETTING_COLOR_SELECT") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_SELECT], charsmax(g_eSettings[SETTING_COLOR_SELECT]))
                    }
                    case SECTION_CORPSE:
                    {
                        if ( equali(szKey, "CORPSE_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_MODEL], charsmax(eCorpse[CORPSE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        else if ( equali(szKey, "CORPSE_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_FLAGS], charsmax(eCorpse[CORPSE_FLAGS]), g_eSettings[SETTING_DEFAULT_FLAGS])
                        else if ( equali(szKey, "CORPSE_SEQUENCE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_SEQUENCE], charsmax(eCorpse[CORPSE_SEQUENCE]), g_eSettings[SETTING_DEFAULT_SEQUENCE])
                        else if ( equali(szKey, "CORPSE_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_FRAMERATE], charsmax(eCorpse[CORPSE_FRAMERATE]), g_eSettings[SETTING_DEFAULT_FRAMERATE])
                        else if ( equali(szKey, "CORPSE_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_SPAWN_CHANCE], charsmax(eCorpse[CORPSE_SPAWN_CHANCE]), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE])
                        else if ( equali(szKey, "CORPSE_MESSAGE") )
                        {
                            if ( !eCorpse[CORPSE_MESSAGE_EXIST] )
                            {
                                ArrayClear(eCorpse[CORPSE_MESSAGE])
                                eCorpse[CORPSE_MESSAGE_EXIST] = true
                                eCorpse[CORPSE_MESSAGE_COUNT] = 0
                            }

                            parseSetting(DTYPE_ARRAY, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_MESSAGE], charsmax(eCorpse[CORPSE_MESSAGE]), g_eSettings[SETTING_DEFAULT_MESSAGE])
                            eCorpse[CORPSE_MESSAGE_COUNT] ++
                        }
                        else if ( equali(szKey, "CORPSE_SOUND") )
                        {
                            if ( !eCorpse[CORPSE_SOUND_EXIST] )
                            {
                                ArrayClear(eCorpse[CORPSE_SOUND])
                                eCorpse[CORPSE_SOUND_EXIST] = true
                                eCorpse[CORPSE_SOUND_COUNT] = 0
                            }

                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_SOUND], charsmax(eCorpse[CORPSE_SOUND]), g_eSettings[SETTING_DEFAULT_SOUND])
                            eCorpse[CORPSE_SOUND_COUNT] ++
                        }
                        else if ( equali(szKey, "CORPSE_SOUND_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_SOUND_COOLDOWN], charsmax(eCorpse[CORPSE_SOUND_COOLDOWN]), g_eSettings[SETTING_DEFAULT_SOUND_COOLDOWN])
                        else if ( equali(szKey, "CORPSE_MINS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_MINS], charsmax(eCorpse[CORPSE_MINS]))
                        else if ( equali(szKey, "CORPSE_MAXS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCorpse[CORPSE_MAXS], charsmax(eCorpse[CORPSE_MAXS]))
                    }
                }
            }
        }
    }

    if ( g_iCorpseConfig )
        ArrayPushArray(g_aCorpseConfig, eCorpse)
    else
        set_fail_state("No Corpses were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    new iItem
    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST]
    && (iItem = pev(g_ePlayerData[id][PDATA_CORPSE_GHOST], CORPSE_ARRAY_ITEM)) != -1 )
    {
        corpseKill(g_ePlayerData[id][PDATA_CORPSE_GHOST])
        corpseRemove(iItem)
    }

    g_ePlayerData[id][PDATA_CORPSE_GHOST]  = 0
    g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
    g_ePlayerData[id][PDATA_CORPSE_MENU]   = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public corpseInit()
{
    if ( g_eSettings[SETTING_CORPSE_LOAD] )
        loadData()
}

public corpseMenu(id, iType)
{
    new szData[64], iMenu
    formatex(szData, charsmax(szData), "%L", id, "CORPSE_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(iMenu);      format(szData, charsmax(szData), "%s^n%L", szData, id, "CORPSE_ROOT_CREATE"); }
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "CORPSE_ROOT_SHOW"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CORPSE_ROOT_REMOVE"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CORPSE_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "CORPSE_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
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

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_NOCLIP", id, get_user_noclip(id) ? "CORPSE_ON" : "CORPSE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CORPSE_ROOT_GODMODE", id, get_user_godmode(id) ? "CORPSE_ON" : "CORPSE_OFF")
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
                corpseSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_CREATE)
            }
        }
        case ROOT_SHOW:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
                corpseSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                corpseSound(id, SOUND_MENU_NAV)
                corpseMenu(id, MENU_SHOW)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCorpse )
            {
                client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_NO_CORPSE")
                corpseSound(id, SOUND_MENU_REMOVE)
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
        case ROOT_NOCLIP:
        {
            corpseNoClip(id)
        }
        case ROOT_GODMODE:
        {
            corpseGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new eCorpse[CORPSE], szItem[64]

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

public menuShow(id, iMenu)
{
    new szItem[64], eCorpse[CORPSE]

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

            if ( eCorpse[CORPSE_SHOW] == SHOW_FORCE_SHOW
            || eCorpse[CORPSE_SHOW] == SHOW_DEFAULT )
            {
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
            }
            else if ( eCorpse[CORPSE_SHOW] == SHOW_FORCE_HIDE )
            {
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_NOT)
                eCorpse[CORPSE_FLAGS] &= ~FLAG_SHOW
            }

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SHOW_CURRENT",
            eCorpse[CORPSE_NAME], id, g_szShowChat[eCorpse[CORPSE_SHOW]])
            ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_SHOW:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
                eCorpse[CORPSE_SHOW] = SHOW_FORCE_SHOW
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SHOW_ALL_SHOWN")
            corpseSound(id, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_HIDE:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] &= ~FLAG_SHOW
                eCorpse[CORPSE_SHOW] = SHOW_FORCE_HIDE
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_NOT)

                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SHOW_ALL_HIDDEN")
            corpseSound(id, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iCorpse; i ++ )
            {
                ArrayGetArray(g_aCorpse, i, eCorpse)
                eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
                eCorpse[CORPSE_SHOW] = SHOW_DEFAULT
                set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
                ArraySetArray(g_aCorpse, i, eCorpse)
            }

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SHOW_ALL_DEFAULT")
            corpseSound(id, SOUND_MENU_ALERT)
            corpseMenu(id, MENU_SHOW)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eCorpse[CORPSE]

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

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CORPSE_MENU] = 0

            corpseSound(id, SOUND_MENU_ALERT)
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

public menuRotate(id, iMenu)
{
    new szItem[64], eCorpse[CORPSE]
    if ( corpseGet(eCorpse, g_ePlayerData[id][PDATA_CORPSE_GHOST]) == -1 )
    {
        menu_destroy(iMenu)
        return
    }

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
    new eCorpse[CORPSE], iItem
    if ( (iItem = corpseGet(eCorpse, g_ePlayerData[id][PDATA_CORPSE_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

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
            corpseTrace(eCorpse, id)
            g_ePlayerData[id][PDATA_CORPSE_GHOST] = 0
            g_ePlayerData[id][PDATA_CORPSE_ACTION] = false

            eCorpse[CORPSE_FLAGS] |= FLAG_SHOW
            eCorpse[CORPSE_FLAGS] &= ~FLAG_GHOST
            eCorpse[CORPSE_NEXT_SOUND] = get_gametime() + random_float(eCorpse[CORPSE_SOUND_COOLDOWN][0], eCorpse[CORPSE_SOUND_COOLDOWN][1])

            if ( eCorpse[CORPSE_FLAGS] & FLAG_ANIM )
                corpseSetAnim(eCorpse)
            if ( eCorpse[CORPSE_FLAGS] & FLAG_SOLID )
                corpseSetSolid(eCorpse)
            ArraySetArray(g_aCorpse, iItem, eCorpse)

            client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_CREATE_NEW", eCorpse[CORPSE_NAME])
            corpseSound(id, SOUND_MENU_NAV)
            corpseMenu(id, MENU_ROOT)
        }
        default:
        {
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
    new eCorpse[CORPSE], szSound[MAX_VALUE_LENGTH], Float:fOrigin[3], Float:fViewOfs[3], Float:fFraction, Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_CORPSE_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_CORPSE_ACTION] )
                corpseCheck(id)
        }
        else if ( corpseGet(eCorpse, g_ePlayerData[id][PDATA_CORPSE_GHOST]) != -1 )
        {
            corpseTrace(eCorpse, id)
        }
    }

    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)
        if ( !(eCorpse[CORPSE_FLAGS] & FLAG_SHOW)
        || !(eCorpse[CORPSE_FLAGS] & FLAG_SOUND) )
            continue

        if ( eCorpse[CORPSE_NEXT_SOUND]
        && fCurrentTime >= eCorpse[CORPSE_NEXT_SOUND] )
        {
            for ( new j = 1; j <= g_iMaxPlayers; j ++ )
            {
                if ( !is_user_alive(j) )
                    continue

                pev(j, pev_origin, fOrigin)
                pev(j, pev_view_ofs, fViewOfs)
                xs_vec_add(fOrigin, fViewOfs, fOrigin)
                engfunc(EngFunc_TraceLine, fOrigin, eCorpse[CORPSE_ORIGIN], IGNORE_MONSTERS, j, 0)
                get_tr2(0, TR_flFraction, fFraction)

                if ( xs_vec_distance(fOrigin, eCorpse[CORPSE_ORIGIN]) <= g_eSettings[SETTING_DEFAULT_SOUND_DISTANCE]
                && fFraction >= 1.0 )
                {
                    ArrayGetArray(eCorpse[CORPSE_SOUND], random(eCorpse[CORPSE_SOUND_COUNT]), szSound)
                    engfunc(EngFunc_EmitSound, eCorpse[CORPSE_ID], CHAN_ITEM, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
                    eCorpse[CORPSE_NEXT_SOUND] = fCurrentTime + random_float(eCorpse[CORPSE_SOUND_COOLDOWN][0], eCorpse[CORPSE_SOUND_COOLDOWN][1])

                    ArraySetArray(g_aCorpse, i, eCorpse)
                    break
                }
            }
        }
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

        eCorpse[CORPSE_FLAGS] |= FLAG_GHOST
    }

    set_pev(iEnt, CORPSE_ARRAY_ITEM, g_iCorpse)
    set_pev(iEnt, pev_impulse, CORPSE_KEY)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_sequence, eCorpse[CORPSE_SEQUENCE])
    engfunc(EngFunc_SetModel, iEnt, eCorpse[CORPSE_MODEL])

    ArrayPushArray(g_aCorpse, eCorpse)
    g_iCorpse ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public corpseRemove(iItem)
{
    new eCorpse[CORPSE]
    ArrayDeleteItem(g_aCorpse, iItem)
    g_iCorpse --

    for ( new i = iItem; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)
        set_pev(eCorpse[CORPSE_ID], CORPSE_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eCorpse[CORPSE],
        szFile[128], iFile,
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

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eCorpse[CORPSE_ORIGIN][0], eCorpse[CORPSE_ORIGIN][1], eCorpse[CORPSE_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        eCorpse[CORPSE_ANGLES][0], eCorpse[CORPSE_ANGLES][1], eCorpse[CORPSE_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "show = %d^n", eCorpse[CORPSE_SHOW])
        fputs(iFile, szData)

        eCorpse[CORPSE_FLAGS] &= ~(FLAG_GHOST | FLAG_SELECT)
        formatex(szData, charsmax(szData), "flags = %d^n", eCorpse[CORPSE_FLAGS])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CORPSE_CHAT_TAG", id, "CORPSE_CHAT_SAVE", szFile)
    fclose(iFile)

    corpseSound(id, SOUND_MENU_NAV)
    corpseMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem,
        iShow, iFlags, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_CorpseSpawn.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataCorpse(fOrigin, fAngles, iShow, iFlags, iItem, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "show") )
            {
                iShow = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataCorpse(fOrigin, fAngles, iShow, iFlags, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataCorpse(Float:fOrigin[3], Float:fAngles[3], iShow, iFlags, iItem, iCount)
{
    new eCorpse[CORPSE]
    corpseCreate(0, iItem)
    ArrayGetArray(g_aCorpse, iCount, eCorpse)

    xs_vec_copy(fOrigin, eCorpse[CORPSE_ORIGIN])
    xs_vec_copy(fAngles, eCorpse[CORPSE_ANGLES])
    set_pev(eCorpse[CORPSE_ID], pev_origin, fOrigin)
    set_pev(eCorpse[CORPSE_ID], pev_angles, fAngles)

    eCorpse[CORPSE_SHOW] = iShow
    eCorpse[CORPSE_FLAGS] = iFlags
    eCorpse[CORPSE_NEXT_SOUND] = get_gametime() + random_float(eCorpse[CORPSE_SOUND_COOLDOWN][0], eCorpse[CORPSE_SOUND_COOLDOWN][1])

    corpseSetBox(eCorpse)
    if ( eCorpse[CORPSE_FLAGS] & FLAG_ANIM )
        corpseSetAnim(eCorpse)
    if ( eCorpse[CORPSE_FLAGS] & (FLAG_SHOW | FLAG_SOLID) )
        corpseSetSolid(eCorpse)

    ArraySetArray(g_aCorpse, iCount, eCorpse)
}

public corpseNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    corpseSound(id, SOUND_MENU_NAV)
    corpseMenu(id, MENU_ROOT)
}

public corpseGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    corpseSound(id, SOUND_MENU_NAV)
    corpseMenu(id, MENU_ROOT)
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

    new eCorpse[CORPSE]
    if ( corpseGet(eCorpse, iEnt) == -1 )
        return FMRES_IGNORED

    new bool:bHidden
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
    else if ( eCorpse[CORPSE_FLAGS] & FLAG_GHOST )
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

    static eCorpse[CORPSE], iEnt, iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST] )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        if ( (iEnt = corpseUse(id))
        && corpseGet(eCorpse, iEnt) != -1
        && eCorpse[CORPSE_FLAGS] & FLAG_SHOW
        && eCorpse[CORPSE_FLAGS] & FLAG_MESSAGE )
        {
            corpseMessage(id, eCorpse)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    g_ePlayerData[id][PDATA_CORPSE_ACTION] = false
    g_ePlayerData[id][PDATA_CORPSE_MENU]   = 0

    if ( g_ePlayerData[id][PDATA_CORPSE_GHOST] )
    {
        new eCorpse[CORPSE], iItem

        if ( (iItem = corpseGet(eCorpse, g_ePlayerData[id][PDATA_CORPSE_GHOST])) != -1 )
        {
            corpseKill(g_ePlayerData[id][PDATA_CORPSE_GHOST])
            corpseRemove(iItem)
        }

        g_ePlayerData[id][PDATA_CORPSE_GHOST] = 0
    }
}

stock corpseTrace(eCorpse[CORPSE], id)
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

stock corpseCheck(id)
{
    new eCorpse[CORPSE], Float:fVec1[3], Float:fVec2[3], Float:fForward[3]
    new iBest, Float:fBestDist, Float:fTraceLength, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fForward)
    engfunc(EngFunc_MakeVectors, fForward)
    global_get(glb_v_forward, fForward)

    xs_vec_mul_scalar(fForward, 9999.9, fVec2)
    xs_vec_add(fVec2, fVec1, fVec2)

    engfunc(EngFunc_TraceLine, fVec1, fVec2, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fVec2)

    iBest = -1
    fBestDist = 20.0
    fTraceLength = get_distance_f(fVec1, fVec2)

    for ( new i = 0; i < g_iCorpse; i ++ )
    {
        ArrayGetArray(g_aCorpse, i, eCorpse)
        xs_vec_sub(eCorpse[CORPSE_ORIGIN], fVec1, fVec2)
        fDot = xs_vec_dot(fVec2, fForward)

        if ( fDot < 0.0 || fDot > fTraceLength )
            continue

        xs_vec_copy(fForward, fVec2)
        xs_vec_mul_scalar(fVec2, fDot, fVec2)
        xs_vec_add(fVec2, fVec1, fVec2)

        fDist = get_distance_f(eCorpse[CORPSE_ORIGIN], fVec2)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_CORPSE_MENU] != iBest )
    {
        ArrayGetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)
        eCorpse[CORPSE_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aCorpse, g_ePlayerData[id][PDATA_CORPSE_MENU], eCorpse)

        ArrayGetArray(g_aCorpse, iBest, eCorpse)
        eCorpse[CORPSE_FLAGS] |= FLAG_SELECT
        ArraySetArray(g_aCorpse, iBest, eCorpse)
        g_ePlayerData[id][PDATA_CORPSE_MENU] = iBest
    }
}

stock corpseUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE)
    || pev(id, pev_oldbuttons) & IN_USE )
        return 0

    new Float:fOrigin[3], Float:fVec1[3], iEnt = -1
    pev(id, pev_origin, fOrigin)
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(fOrigin, fVec1, fOrigin)

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_eSettings[SETTING_CORPSE_RANGE], fVec1)
    xs_vec_add(fVec1, fOrigin, fVec1)

    engfunc(EngFunc_TraceLine, fOrigin, fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fOrigin)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 10.0)) )
    {
        if ( !pev_valid(iEnt) || !isCorpse(iEnt) )
            continue

        return iEnt
    }

    return 0
}

public corpseMessage(id, eCorpse[CORPSE])
{
    new szMsg[1024]
    ArrayGetString(eCorpse[CORPSE_MESSAGE], random(eCorpse[CORPSE_MESSAGE_COUNT]), szMsg, charsmax(szMsg))

    show_menu(id, MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9, szMsg, random_num(g_eSettings[SETTING_DEFAULT_MESSAGE_TIMEOUT][0], g_eSettings[SETTING_DEFAULT_MESSAGE_TIMEOUT][1]))
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
    new Float:fMins[3], Float:fMaxs[3]
    set_pev(eCorpse[CORPSE_ID], pev_solid, SOLID_BBOX)
    set_pev(eCorpse[CORPSE_ID], pev_movetype, MOVETYPE_NONE)

    xs_vec_copy(eCorpse[CORPSE_MINS], fMins)
    xs_vec_copy(eCorpse[CORPSE_MAXS], fMaxs)
    engfunc(EngFunc_SetSize, eCorpse[CORPSE_ID], fMins, fMaxs)
    set_rendering(eCorpse[CORPSE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock corpseSetAnim(eCorpse[CORPSE])
{
    set_pev(eCorpse[CORPSE_ID], pev_frame, 0)
    set_pev(eCorpse[CORPSE_ID], pev_framerate, eCorpse[CORPSE_FRAMERATE])
    set_pev(eCorpse[CORPSE_ID], pev_animtime, get_gametime())
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

stock corpseGet(eCorpse[CORPSE], iEnt)
{
    new iItem
    iItem = pev(iEnt, CORPSE_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iCorpse )
        return -1

    ArrayGetArray(g_aCorpse, iItem, eCorpse)
    return iItem
}

stock bool:isCorpse(iEnt)
{
    return pev(iEnt, pev_impulse) == CORPSE_KEY
}

stock corpseKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szKey[], iKeyLen, szValue[], iValueLen, any:output[], iOutputLen, const any:fallback[] = {0.0, 0.0})
{
    switch ( iType )
    {
        case DTYPE_FLOAT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)
            output[1] = str_to_float(szValue)

            if ( output[0] < 0.0 ) output[0] = fallback[0]
            if ( output[1] < 0.0 ) output[1] = fallback[1]
        }
        case DTYPE_FLOAT:
        {
            output[0] = str_to_float(szValue)
            if ( output[0] < 0.0 ) output[0] = fallback[0]
        }
        case DTYPE_INT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)
            output[1] = str_to_num(szValue)

            if ( output[0] < 0 ) output[0] = fallback[0]
            if ( output[1] < 0 ) output[1] = fallback[1]
        }
        case DTYPE_INT:
        {
            output[0] = str_to_num(szValue)
            if ( output[0] < 0 ) output[0] = fallback[0]
        }
        case DTYPE_BOOL:
        {
            output[0] = bool:str_to_num(szValue)
        }
        case DTYPE_FLAGS:
        {
            output[0] = read_flags(szValue)
        }
        case DTYPE_VECTOR:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_num(szKey)
            output[2] = str_to_num(szValue)
        }
        case DTYPE_VECTOR_FLOAT:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_float(szKey)
            output[2] = str_to_float(szValue)
        }
        case DTYPE_ARRAY:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(output[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(output[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_SPRITE:
        {
            if ( !g_bFileWasRead )
                output[0] = precache_model(szValue)
        }
    }
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}


