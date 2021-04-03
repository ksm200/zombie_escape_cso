#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <sqlx>
#include <fakemeta>
#include <print_center_fx>

/*

	CREATE TABLE zp_cuentas 
	(
		id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
		Pj varchar(34) NOT NULL UNIQUE KEY, 
		Password varchar(34) NOT NULL,
		status_steam int(10) NOT NULL DEFAULT '0',
		steam_id varchar(40) NOT NULL
	);

*/
enum
{
	REGISTRAR_CUENTA,
	LOGUEAR_CUENTA,
	CARGAR_DATOS,
	IS_REGISTER,
	GUARDAR_DATOS,
	TOTAL_CUENTAS
};

enum
{
	NO_REGISTRADO = 0,
	DESCONECTADO,
	REGISTRADO,
	LOGUEADO,
	MAX_STATUS
}

//No cambiar autor por m�s que lo uses para otro modo, no seas rata, no importa si lo reescribes media ves te bases en este
new const PluginName[] = "System Account";
new const PluginVersion[] = "1.0";
new const PluginAuthor[] = "Hypnotize";
//No cambiar autor por m�s que lo uses para otro modo, no seas rata, no importa si lo reescribes media ves te bases en este

//apartado para escribir el nombre del creador del mod
//area modificable
new const ModName[] = "Zombie Escape CSO";//nombre del mod
new const ModAuthor[] = "Hypnotize - divstarproject.com"; //ac� pones tu nombre si lo usaste para un modo tuyo
new const ModVersion[] = "1.0b";//versi�n del modo
new const g_szForo[] = "lwfservers.net/foro/";
//apartado para escribir el nombre del creador del mod
//area modificable

new const g_szTabla[ ] = "zp_cuentas";
new const g_szPrefijo[ ] = "[ZE]";

new const MYSQL_HOST[] = "45.58.56.194";
new const MYSQL_USER[] = "root";
new const MYSQL_PASS[] = "MiFaMiLia321_3";
new const MYSQL_DATEBASE[] = "scs_christopher";

new Handle:g_hTuple;

new g_fwLogin;
new g_iTotalRegister;
new g_estado[ 33 ];
new g_id[ 33 ];
new g_szPassword[ 33 ][ 34 ];
new g_szPlayerName[ 33 ][ 33 ], g_szSteam[ 33 ][ 34 ], g_szSteamDB[ 33 ][ 34 ];
new g_iData[ 33 ], g_iStatus_steam[ 33 ];

const m_iVGUI = 510;
const TIEMPO_LOGUEO = 35465;

new g_iTime[ 33 ];

public plugin_init()  
{
	register_plugin( 
		PluginName, 
		PluginVersion, 
		PluginAuthor 
	);

	register_clcmd("CREAR_PASSWORD", "register_account");
	register_clcmd("LOGUEAR_PASSWORD", "login_account");

	register_forward(FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged");
	RegisterHookChain( RG_CBasePlayer_RoundRespawn, "fw_respawn_post", true );

	RegisterHookChain(RG_ShowVGUIMenu, "message_VGUImenu");
	RegisterHookChain(RG_ShowMenu, "message_showmenu");
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "message_showmenu");
	
	g_fwLogin = CreateMultiForward("user_login_post", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_iTotalRegister = 0;

	Mysql_init( );
}

public plugin_natives()
{
	register_native("is_registered", "native_register", 1);
	register_native("is_logged", "native_logged", 1);
	register_native("show_login_menu", "native_login", 1);
	register_native("sqlConection", "handler_connection", 1);
}

public Handle:handler_connection()
	return g_hTuple;

public native_login(id)
	return show_login_menu(id);

public native_register(id)
	return g_estado[ id ] == REGISTRADO ? true : false;

public native_logged(id)
	return g_estado[ id ] == LOGUEADO ? true : false;

public message_VGUImenu( const id, VGUIMenu: iMenu, const iBitsSlots, const szOldMenu[], const bool: bForceOldMenu )
{
	if( iMenu != VGUI_Menu_Team || g_estado[ id ] >= LOGUEADO )
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

public message_showmenu( iMsgid, iDest, id ) 
{
	if( g_estado[ iMsgid ] >= LOGUEADO )
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

public show_login_menu( id ) 
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(!g_iData[id])
	{
		client_print(id, print_chat, "Espera un momento, tus datos est�n siendo buscados..");
		client_print(id, print_chat, "Espera un momento, tus datos est�n siendo buscados..");
		client_print(id, print_chat, "Espera un momento, tus datos est�n siendo buscados..");
		return PLUGIN_HANDLED;
	}

	static menu, info[200]; 

	formatex(info, charsmax(info), "\wBIENVENIDOS AL \y%s \r(%s)\w^n\wCreador: \r%s", ModName, ModVersion, ModAuthor);
	menu = menu_create(info, "menu_login" );
	
	if(g_estado[ id ] >= REGISTRADO)
		menu_additem( menu, "\dCrear una Cuenta / Create an account" );
	else
		menu_additem( menu, "\wCrear una Cuenta / Create an account" );

	if(g_estado[ id ] >= REGISTRADO)
		menu_additem( menu, "\wIdentificarse / Login" );
	else
		menu_additem( menu, "\dIdentificarse / Login" );
	
	formatex(info, charsmax(info), "^n\wCuentas Registradas\w: \y#%d", g_iTotalRegister);
	menu_addtext(menu, info);

	formatex(info, charsmax(info), "^n\wForo\r: \y%s", g_szForo);
	menu_addtext(menu, info);

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public menu_login( id, menu, item ) 
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch( item ) 
	{
		case 0: 
		{
			if(g_estado[ id ] >= REGISTRADO)
				client_print(id, print_center, "%s Esta Cuenta ya esta registrada.", g_szPrefijo);
			else
				client_cmd( id, "messagemode CREAR_PASSWORD" );
		}
		case 1:
		{
			if(g_estado[ id ] >= REGISTRADO)
				client_cmd( id, "messagemode LOGUEAR_PASSWORD" );
			else
				client_print(id, print_center, "%s Tu cuenta aun no existe.", g_szPrefijo);
		}
	}
	return PLUGIN_HANDLED;
}

public register_account( id ) 
{
	read_args( g_szPassword[ id ], charsmax( g_szPassword[ ] ) );
	remove_quotes( g_szPassword[ id ] );
	trim( g_szPassword[ id ] );
	hash_string( g_szPassword[ id ], Hash_Md5, g_szPassword[ id ], charsmax( g_szPassword[] ) );
	
	new szQuery[ 256 ], iData[ 2 ], szSteam[ 40 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = REGISTRAR_CUENTA;

	get_user_authid( id, szSteam, charsmax( szSteam ) );

	g_iStatus_steam[ id ] = is_user_steam( id ) ? 1 : 0;

	formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (Pj, Password, status_steam, steam_id) VALUES (^"%s^", ^"%s^", %d, ^"%s^")", g_szTabla, g_szPlayerName[ id ], g_szPassword[ id ], g_iStatus_steam[ id ], szSteam );
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
	
	return PLUGIN_HANDLED;
}
public login_account( id ) 
{
	read_args( g_szPassword[ id ], charsmax( g_szPassword[ ] ) );
	remove_quotes( g_szPassword[ id ] );
	trim( g_szPassword[ id ] );
	hash_string( g_szPassword[ id ], Hash_Md5, g_szPassword[ id ], charsmax( g_szPassword[] ) );
	
	new szQuery[ 128 ], iData[ 2 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = LOGUEAR_CUENTA;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj=^"%s^" AND Password=^"%s^"", g_szTabla, g_szPlayerName[ id ], g_szPassword[ id ] );
	SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
	
	return PLUGIN_HANDLED;
}
public DataHandlerServer( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:time ) 
{
	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_CUENTAS_LOG.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
			log_to_file( "SQL_CUENTAS_LOG.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	switch( data[ 0 ] ) 
	{
		case TOTAL_CUENTAS:
		{
			if(SQL_NumResults( Query ))
			{
				g_iTotalRegister = SQL_ReadResult( Query, 0 );
			}
		}
	}
}
public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:time ) 
{
	new id = data[ 0 ];
	
	if( !is_user_connected( id ) )
		return;

	switch( failstate ) 
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_to_file( "SQL_LOG_TQ.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
			return;
		}
		case TQUERY_QUERY_FAILED:
			log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
	}
	
	switch( data[ 1 ] ) 
	{
		case REGISTRAR_CUENTA: 
		{
			if( failstate < TQUERY_SUCCESS ) 
			{
				if( containi( error, "Pj" ) != -1 )
					client_print( id, print_chat, "%s El nombre de personaje esta en uso.", g_szPrefijo );
				else
					client_print( id, print_chat, "%s Error al crear la cuenta. Intente nuevamente.", g_szPrefijo );
				
				client_cmd( id, "spk buttons/button10.wav" );
				
				show_login_menu( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Tu cuenta ha sido creada correctamente.", g_szPrefijo );
				
				new szQuery[ 128 ], iData[ 2 ];
				
				iData[ 0 ] = id;
				iData[ 1 ] = CARGAR_DATOS;

				g_estado[ id ] = REGISTRADO;
				
				formatex( szQuery, charsmax( szQuery ), "SELECT id FROM %s WHERE Pj=^"%s^"", g_szTabla, g_szPlayerName[ id ] );
				SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
			}
			
		}
		case LOGUEAR_CUENTA: 
		{
			if( SQL_NumResults( Query ) ) 
			{
				g_id[ id ] = SQL_ReadResult( Query, 0 );
				g_iStatus_steam[ id ] = SQL_ReadResult( Query, 3 );
				//get_steam

				SQL_ReadResult( Query, 1, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );					
				
				new iRet; ExecuteForward(g_fwLogin, iRet, id, g_id[ id ]);
			
				client_print( id, print_chat, "%s BIENVENIDO %s.", g_szPrefijo, g_szPlayerName[ id ]);
				client_print( id, print_chat, "%s TU ID DE CUENTA ES %d.", g_szPrefijo, g_id[ id ]);
				
				func_login_success( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Usuario o Contraseñ incorrecta.", g_szPrefijo );
				client_cmd( id, "spk buttons/button10.wav" );
				
				show_login_menu( id );
			}
		}
		case CARGAR_DATOS: 
		{
			if( SQL_NumResults( Query ) ) 
			{
				g_id[ id ] = SQL_ReadResult( Query, 0 );
				g_iStatus_steam[ id ] = is_user_steam( id ) ? 1 : 0;
				
				new iRet; ExecuteForward(g_fwLogin, iRet, id, g_id[ id ]);

				client_print( id, print_chat, "%s BIENVENIDO %s.", g_szPrefijo, g_szPlayerName[ id ]);
				client_print( id, print_chat, "%s TU ID DE CUENTA ES %d", g_szPrefijo, g_id[ id ]);
				
				func_login_success( id );
			}
			else 
			{
				client_print( id, print_chat, "%s Error al cargar los datos, intente nuevamente.", g_szPrefijo );
				show_login_menu( id );
			}
		}
		case IS_REGISTER:
		{
			if( SQL_NumResults( Query ) )
			{
				g_estado[ id ] = REGISTRADO;
				g_iStatus_steam[ id ] = SQL_ReadResult( Query, 3 );
				SQL_ReadResult( Query, 4, g_szSteamDB[ id ], charsmax( g_szSteamDB[ ] ) );
			}
			else
			{
				g_estado[ id ] = NO_REGISTRADO;
			}

			g_iData[ id ] = 1;
			/*g_iData[id] = 1;
			set_task(0.8, "show_login_menu", id);
			set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");*/

			if( g_estado[ id ] == REGISTRADO )
			{
				if( is_user_steam( id ) )
				{
					if( g_iStatus_steam[ id ] )
					{
						if( equal( g_szSteamDB[ id ], g_szSteam[ id ] ) )
						{
							//autolog
							new szQuery[ 128 ], iData[ 2 ];
	
							iData[ 0 ] = id;
							iData[ 1 ] = LOGUEAR_CUENTA;
							
							formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj=^"%s^" AND steam_id=^"%s^"", g_szTabla, g_szPlayerName[ id ], g_szSteam[ id ] );
							SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
							console_print( 0, "AUTOLOG");
						}
						else
						{
							//entraste con otro steam
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							client_print_color( id, print_team_blue, "Entraste con otro steam!");
							console_print( 0, "OTRO STEAM LOG");
						}
					}
					else
					{
						set_task(0.8, "show_login_menu", id);
						set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
						console_print( 0, "LOGIN STATUS 0");
					}
				}
				else
				{
					if( g_iStatus_steam[ id ] )
					{
						//es steam entro en no steam
						client_print_color( id, print_team_blue, "Entraste con otro steam!");
						client_print_color( id, print_team_blue, "Entraste con otro steam!");
						client_print_color( id, print_team_blue, "Entraste con otro steam!");

						console_print( 0, "NO STEAM / STEAM");
					}
					else
					{
						set_task(0.8, "show_login_menu", id);
						set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
						console_print( 0, "LOGIN STEAM");
					}
					
				}
			}
			else
			{
				set_task(0.8, "show_login_menu", id);
				set_task(1.0, "logueo_cuenta", TIEMPO_LOGUEO+id, _, _, "b");
			}
		}
		case GUARDAR_DATOS:
		{
			if( failstate < TQUERY_SUCCESS )
				console_print( id, "Error en el guardado de datos." );
			else
			console_print( id, "Datos guardados." );
		}
	}
}

public logueo_cuenta( taskid )
{
	static id; 
	id = taskid - TIEMPO_LOGUEO;

	if( g_iTime[id] <= 0 )
	{
		remove_task(TIEMPO_LOGUEO+id);
		server_cmd("kick #%d",  get_user_userid(id));
		return;
	}

	client_print(id, print_center, "Tienes %d segundos para loguearte", g_iTime[id]);

	g_iTime[id]--;
}

public func_login_success( id ) 
{
	if( is_user_connected(id) )
	{
		rg_join_team( id, rg_get_join_team_priority( ) );

		g_estado[ id ] = LOGUEADO;
		
		set_user_info( id, "name", g_szPlayerName[ id ] );

		remove_task(TIEMPO_LOGUEO+id);
	}
		
}

public fw_respawn_post( id )
{
	if( !is_user_connected( id ) ) 
		return;

	if( is_user_steam( id ) && !g_iStatus_steam[ id ] )
	{
		new szQuery[ MAX_MOTD_LENGTH ], iData[ 2 ];

		iData[ 0 ] = id;
		iData[ 1 ] = GUARDAR_DATOS;

		formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET status_steam = 1, steam_id=^"%s^" WHERE id = '%d'", g_szTabla, g_szSteam[ id ], g_id[ id ] );
		SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
	}	
}

public fw_ClientUserInfoChanged(id, buffer) 
{
    if (!is_user_connected(id)) 
    	return FMRES_IGNORED;
    
    static Name[32], Old[32];
    get_user_name(id, Name, charsmax(Name));
    get_user_info(id, "name", Old, charsmax(Old))

    if (equal(Old, Name)) 
    	return FMRES_IGNORED;
    
    set_user_info(id, "name", g_szPlayerName[ id ]);
    return FMRES_IGNORED;
} 

public client_putinserver( id )
{
	if( is_user_bot( id ) )
		return;

	get_user_name( id, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );
	get_user_authid( id, g_szSteam[ id ], charsmax( g_szSteam[ ] ) );

	g_iData[id] = 0;
	g_iTime[ id ] = 60;

	check_register( id );
}

public check_register( id )
{
	new szQuery[ 256 ], iData[ 2 ];
	
	iData[ 0 ] = id;
	iData[ 1 ] = IS_REGISTER;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE Pj = ^"%s^"", g_szTabla, g_szPlayerName[ id ]);
	SQL_ThreadQuery(g_hTuple, "DataHandler", szQuery, iData, 2);
}

public client_disconnected(  id ) 
{
	if( g_estado[ id ] ) 
	{
		g_estado[ id ] = DESCONECTADO;
	}
	g_szPassword[ id ][ 0 ] = EOS;

	remove_task(TIEMPO_LOGUEO+id);
}

public Mysql_init()
{
	g_hTuple = SQL_MakeDbTuple( MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATEBASE );
	
	if( !g_hTuple ) 
	{
		log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
		return pause( "a" );
	}
	new szQuery[ 256 ], iData[ 1 ];
	
	iData[ 0 ] = TOTAL_CUENTAS;
	
	formatex( szQuery, charsmax( szQuery ), "SELECT COUNT(*) FROM %s", g_szTabla);
	SQL_ThreadQuery(g_hTuple, "DataHandlerServer", szQuery, iData, 2);
	return PLUGIN_CONTINUE;
}

public plugin_end()
	SQL_FreeHandle( g_hTuple );
