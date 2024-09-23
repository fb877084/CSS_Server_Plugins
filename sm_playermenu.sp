#include <sourcemod>
#include <sdktools>
#include <menus>
#include <cstrike>

#define PLUGIN_VERSION "1.0"
#define PROTECTION_COST 8000
#define SPEED_MULTIPLIER 1.15

bool g_isProtected[MAXPLAYERS + 1] = {false}; // 保護狀態儲存
bool g_isHitman[MAXPLAYERS + 1] = {false}; // 刺客狀態保存
int g_knifeProtection[MAXPLAYERS + 1] = {0}; // 每位玩家的擋刀次數 (最多5次)
float g_PlayerDefaultSpeed[MAXPLAYERS + 1]; // 儲存玩家的預設速度

public Plugin:myinfo = 
{
    name = "[CSS] Player Fun Menu Plugin",
    author = "microusb",
    description = "Displays a fun menu when a player types 'menu' in chat.",
    version = "1.0"
}

public OnPluginStart()
{
	// 註冊聊天命令
	RegConsoleCmd("menu", Cmd_ShowMenu);
	RegConsoleCmd("bobi", Cmd_StabProtect);

	// 註冊聊天事件來監聽玩家聊天
	HookEvent("player_say", OnPlayerSay);
	
	// Hook player hurt event
	HookEvent("player_hurt", Event_player_stabbed, EventHookMode_Pre);
	
	// 註冊玩家死亡後的事件
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	// 註冊回合開始事件
	HookEvent("round_start", Event_PlayerDeath, EventHookMode_Post);
	
}

//玩家死亡或重生後的事件
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_isHitman[client] = false;
	}
	
	return Plugin_Handled;
}

// 玩家在聊天室輸入指令時觸發
public Action Cmd_StabProtect(int client, int args)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
	{
		g_isProtected[client] = true;
		g_knifeProtection[client] = 20; // 給予ADM 20次擋刀次數
		PrintToChat(client, "你已成功獲得刀刺保護20次！");
	}
	else if (GetClientMoney(client) >= PROTECTION_COST)
	{
		int randomChance = GetRandomInt(1, 100);
		if (randomChance <= 35)
		{
			// 扣除費用並給予保護
			g_isProtected[client] = true;
			g_knifeProtection[client] = 5; // 給予玩家5次擋刀次數
			PrintToChat(client, "禱告上達天聽, 已獲得擋刀次數：5次!");
		}
		else
		{
			PrintToChat(client, "你的錢含有假鈔! 加持失敗~");
		}
		RemovePlayerMoney(client, PROTECTION_COST);
	} 
	else 
	{
		// 金錢不足提醒
		PrintToChat(client, "你的現金不足以購買刀刺保護 (需要 %d)！", PROTECTION_COST);
	}
	return Plugin_Handled;
}

// 事件處理：當玩家被攻擊時觸發
public Action:Event_player_stabbed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!g_isProtected[victim]) // 如果玩家沒有保護，直接返回
		return Plugin_Handled;
	if (GetClientTeam(attacker) == GetClientTeam(victim))  // 如果玩家同一隊, 直接返回
		return Plugin_Handled;

	decl String:weaponName[32];
	GetEventString(event, "weapon", weaponName, sizeof(weaponName));

	//if (1)
	if (StrEqual(weaponName, "knife") && g_knifeProtection[victim] > 0) //被小刀砍且保護次數還有
	{
		// 玩家有保護，並且受到刀刺攻擊，恢復血量
		// 取得攻擊造成的實際傷害值
		new damage = GetEventInt(event, "dmg_health");
		new vHealth = GetClientHealth(victim);
		SetEntityHealth(victim, vHealth + damage);
		
		if (g_isHitman[attacker] && !(GetUserFlagBits(victim) & ADMFLAG_ROOT)) //超級ADM無視刺客
		{
			g_knifeProtection[victim] = 0; //扣除所有保護次數
			PrintToChat(victim, "\x04%N \x03遇到職業刀客 \x04%N, \x03強制出險後拒保！", victim, attacker);
		}
		else {
			g_knifeProtection[victim]--; //用掉了一次保護次數
			PrintToChatAll("\x04%N \x03拿刀捅了有買保險的玩家 \x04%N！", attacker, victim);
		}
		
		// 如果次數用完，取消保護
		if (g_knifeProtection[victim] <= 0) 
		{
			g_isProtected[victim] = false;
			PrintToChat(victim, "你的擋刀保護已用完！");
		}
		else
		{
			// 告知玩家剩餘次數
			PrintToChat(victim, "擋刀保險生效！剩餘次數: %d", g_knifeProtection[victim]);
		}
	}

	return Plugin_Handled;
}

// 取得玩家的現金數量
stock int GetClientMoney(int client)
{
	return GetEntProp(client, Prop_Send, "m_iAccount");
}

// 扣除玩家金錢
stock void RemovePlayerMoney(int client, int amount)
{
	SetEntProp(client, Prop_Send, "m_iAccount", GetClientMoney(client) - amount);
}


public DisarmPlayer(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		new weaponid;
		for (new repeat = 0; repeat < 2; repeat++)
		{
			for (new wepID = 0; wepID <= 11; wepID++)
			{
				weaponid = GetPlayerWeaponSlot(client, wepID);
				if (weaponid != -1)
				{
					RemovePlayerItem(client, weaponid);
				}
			}
		}
		GivePlayerItem(client, "weapon_knife");
	}
}

// 檢查是否有效的玩家
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

// 設置玩家的移動速度倍率
stock void SetEntitySpeedMultiplier(int client, float multiplier)
{
    // 如果尚未儲存過玩家的預設速度，則儲存之
    if (g_PlayerDefaultSpeed[client] == 0.0)
    {
        g_PlayerDefaultSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
    }

    // 設置新的速度
    SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", g_PlayerDefaultSpeed[client] * multiplier);
}

public Action:OnPlayerSay(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    // 獲取玩家的聊天訊息
    decl String:message[128];
    GetEventString(event, "text", message, sizeof(message));

    // 如果玩家輸入 "menu" (不區分大小寫)
    if (StrEqual(message, "menu", false))
    {
        // 顯示選單
        ShowMainMenu(client);
    }

    return Plugin_Handled;
}

public Action:Cmd_ShowMenu(int client, int args)
{
    // 檢查玩家是否有效
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    // 建立並顯示選單
    ShowMainMenu(client);
    
    return Plugin_Handled;
}

// 顯示選單的函數
public void ShowMainMenu(int client)
{
    // 創建選單
    new Handle:menu = CreateMenu(MenuHandler_MainMenu);

    // 設定選單標題
    SetMenuTitle(menu, "主選單");

    // 添加選單項目
    AddMenuItem(menu, "1", "買拚刀護身符");
    AddMenuItem(menu, "2", "我要當刺客");
    AddMenuItem(menu, "3", "神秘的選項");

    // 顯示選單給玩家，並設定超時為 10 秒
    DisplayMenu(menu, client, 10);
}

// 處理玩家選擇選單項目的函數
public int MenuHandler_MainMenu(Handle:menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        // 根據玩家選擇的項目執行對應的操作
        switch (item)
        {
            case 0:
			{
                //PrintToChat(client, "你選擇了選項 1");
				FakeClientCommand(client, "bobi");
			}
            case 1:
			{
                //PrintToChat(client, "你選擇了選項 2");
				DisarmPlayer(client);
				SetEntitySpeedMultiplier(client, SPEED_MULTIPLIER);
				SetEntityHealth(client, 350);
				SetEntityRenderMode(client, RENDER_NONE);
				g_isHitman[client] = true;
				
				PrintToChat(client, "化身刺客, 潛入暗影之中！");
			}
            case 2:
			{
                PrintToChat(client, "你選擇了神秘的選項");
			}
        }
    }
    else if (action == MenuAction_Cancel)
    {
        // 處理選單取消
        PrintToChat(client, "選單已取消");
    }

    // 關閉選單
    CloseHandle(menu);
    
    return 0;
}
