/*
THIS FILE IS HEREBY RELEASED UNDER THE Public Domain
This script is released public domain, unlike other ZC scripts for a specific and limited reason, because we want to encourage third party plugin creators to create for zCollar and use whatever permissions on their own work they see fit.  No portion of zCollar derived code may be used with the exception of this script,  without the accompanying GPLv2 license.
-Authors Attribution-
Aria (tiff589) - (August 2020)
Lysea - (December 2020)
*/
#include "MasterFile.lsl"

integer API_CHANNEL = 0x60b97b5e;

//list g_lCollars;
string g_sAddon = "Test Addon";


/*
 * Since Release Candidate 1, Addons will not receive all link messages without prior opt-in.
 * To opt in, add the needed link messages to g_lOptedLM = [], they'll be transmitted on
 * the initial registration and can be updated at any time by sending a packet of type `update`
 * Following LMs require opt-in:
 * [ALIVE, READY, STARTUP, CMD_ZERO, MENUNAME_REQUEST, MENUNAME_RESPONSE, MENUNAME_REMOVE, SAY, NOTIFY, DIALOG, SENSORDIALOG]
 */
list g_lOptedLM     = [];


Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    
    llRegionSayTo(g_kCollar, API_CHANNEL, llList2Json(JSON_OBJECT, [ "pkt_type", "from_addon", "addon_name", g_sAddon, "iNum", DIALOG, "sMsg", (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, "kID", kMenuID ]));

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [ kID, kMenuID, sName ], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Menu App]";
    list lButtons  = ["A Button"];
    
    //llSay(0, "opening menu");
    Dialog(kID, sPrompt, lButtons, ["DISCONNECT", UPMENU], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (llSubStringIndex(llToLower(sStr), llToLower(g_sAddon)) && llToLower(sStr) != "menu " + llToLower(g_sAddon)) return;
    if (iNum & C_COLLAR_INTERNALS && llToLower(sStr) == "runaway") {
        return;
    }

    if (llToLower(sStr) == llToLower(g_sAddon) || llToLower(sStr) == "menu "+llToLower(g_sAddon))
    {
        Menu(kID, iNum);
    } //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else
    {
        //integer iWSuccess   = 0; 
        //string sChangetype  = llList2String(llParseString2List(sStr, [" "], []),0);
        //string sChangevalue = llList2String(llParseString2List(sStr, [" "], []),1);
        //string sText;
    }
}

Link(string packet, integer iNum, string sStr, key kID){
    list packet_data = [ "pkt_type", packet, "iNum", iNum, "addon_name", g_sAddon, "bridge", FALSE, "sMsg", sStr, "kID", kID ];

    if (packet == "online" || packet == "update") // only add optin if packet type is online or update
    {
        packet_data += [ "optin", llDumpList2String(g_lOptedLM, "~") ];
    }

    string pkt = llList2Json(JSON_OBJECT, packet_data);
    if (g_kCollar != "" && g_kCollar != NULL_KEY)
    {
        llRegionSayTo(g_kCollar, API_CHANNEL, pkt);
    }
    else
    {
        llRegionSay(API_CHANNEL, pkt);
    }
}

key g_kCollar=NULL_KEY;
integer g_iLMLastRecv;
integer g_iLMLastSent;

default
{
    state_entry()
    {
        llOwnerSay("@clear");
        API_CHANNEL = ((integer)("0x" + llGetSubString((string)llGetOwner(), 0, 8))) + 0xf6eb - 0xd2;
        llListen(API_CHANNEL, "", "", "");
        Link("online", 0, "", llGetOwner()); // This is the signal to initiate communication between the addon and the collar
        llSetTimerEvent(60);
    }
    
    timer()
    {
        if (llGetUnixTime() >= (g_iLMLastSent + 30))
        {
            g_iLMLastSent = llGetUnixTime();
            Link("ping", 0, "", g_kCollar);
        }

        if(llGetUnixTime() >= (g_iLMLastRecv + (5*60)) && g_kCollar != NULL_KEY){
            llResetScript();
        }
        
        if (g_kCollar == NULL_KEY) Link("online", 0, "", llGetOwner());
    }
    
    listen(integer channel, string name, key id, string msg){
        string sPacketType = llJsonGetValue(msg, ["pkt_type"]);
        if (sPacketType == "approved" && g_kCollar == NULL_KEY)
        {
            // This signal, indicates the collar has approved the addon and that communication requests will be responded to if the requests are valid collar LMs.
            g_kCollar = id;
            g_iLMLastRecv = llGetUnixTime();
            Link("from_addon", LM_SETTING_REQUEST, "ALL", "");
        }
        else if (sPacketType == "dc" && g_kCollar == id)
        {
            g_kCollar = NULL_KEY;
            llResetScript(); // This addon is designed to always be connected because it is a test
        }
        else if (sPacketType == "pong" && g_kCollar == id)
        {
            g_iLMLastRecv = llGetUnixTime();
        }
        else if(sPacketType == "from_collar")
        {
            // process link message if in range of addon
            if (llVecDist(llGetPos(), llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0)) <= 10.0)
            {
                integer iNum = (integer) llJsonGetValue(msg, ["iNum"]);
                string sStr  = llJsonGetValue(msg, ["sMsg"]);
                key kID      = (key) llJsonGetValue(msg, ["kID"]);
                
                if (iNum == LM_SETTING_RESPONSE)
                {
                    list lPar     = llParseString2List(sStr, ["_","="], []);
                    string sToken = llList2String(lPar, 0);
                    string sVar   = llList2String(lPar, 1);
                    string sVal   = llList2String(lPar, 2);
                    
                    if (sToken == "auth")
                    {
                        if (sVar == "owner")
                        {
                            //llSay(0, "owner values is: " + sVal);
                        }
                    }
                }
                else if (iNum == COMMAND)
                {
                    list lTmp = llParseString2List(sStr,["|>"],[]);
                    integer iMask = llList2Integer(lTmp,0);
                    string sCmd = llList2String(lTmp,1);
                    if(!(iMask&(C_OWNER|C_TRUSTED|C_WEARER)))return; 
                    UserCommand(iMask, sCmd, kID);
                    
                }
                else if (iNum == DIALOG_TIMEOUT)
                {
                    integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
                    g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex + 3);  //remove stride from g_lMenuIDs
                }
                else if (iNum == DIALOG_RESPONSE)
                {
                    integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
                    if (iMenuIndex != -1)
                    {
                        string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                        g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                        list lMenuParams = llParseString2List(sStr, ["|"], []);
                        key kAv = llList2Key(lMenuParams, 0);
                        string sMsg = llList2String(lMenuParams, 1);
                        integer iAuth = llList2Integer(lMenuParams, 3);
                        
                        if (sMenu == "Menu~Main")
                        {
                            if (sMsg == UPMENU)
                            {
                                Link("from_addon", 0, "menu Addons", kAv);
                            }
                            else if (sMsg == "A Button")
                            {
                                llSay(0, "This is an example addon.");
                            }
                            else if (sMsg == "DISCONNECT")
                            {
                                Link("offline", 0, "", llGetOwnerKey(g_kCollar));
                                g_lMenuIDs = [];
                                g_kCollar = NULL_KEY;
                            }
                        }
                    }
                }
            }
        }
    }
}
