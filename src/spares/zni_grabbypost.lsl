/*
This file is a part of zCollar
Copyright 2021

: Contributors :
    * April 2021        - Created zni_grabbypost


et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar

*/

integer API_CHANNEL = 0x60b97b5e;

//list g_lCollars;
string g_sAddon = "Grabby Post";

//integer CMD_ZERO            = 0;
integer CMD_OWNER           = 500;
//integer CMD_TRUSTED         = 501;
//integer CMD_GROUP           = 502;
integer CMD_WEARER          = 503;
integer CMD_EVERYONE        = 504;
//integer CMD_BLOCKED         = 598; // <--- Used in auth_request, will not return on a CMD_ZERO
//integer CMD_RLV_RELAY       = 507;
//integer CMD_SAFEWORD        = 510;
//integer CMD_RELAY_SAFEWORD  = 511;
//integer CMD_NOACCESS        = 599;

//integer LM_SETTING_SAVE     = 2000; //scripts send messages on this channel to have settings saved, <string> must be in form of "token=value"
integer LM_SETTING_REQUEST  = 2001; //when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002; //the settings script sends responses on this channel
//integer LM_SETTING_DELETE   = 2003; //delete token from settings
//integer LM_SETTING_EMPTY    = 2004; //sent when a token has no value

integer DIALOG          = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT  = -9002;

/*
 * Since Release Candidate 1, Addons will not receive all link messages without prior opt-in.
 * To opt in, add the needed link messages to g_lOptedLM = [], they'll be transmitted on
 * the initial registration and can be updated at any time by sending a packet of type `update`
 * Following LMs require opt-in:
 * [ALIVE, READY, STARTUP, CMD_ZERO, MENUNAME_REQUEST, MENUNAME_RESPONSE, MENUNAME_REMOVE, SAY, NOTIFY, DIALOG, SENSORDIALOG]
 */
list g_lOptedLM     = [];

list g_lMenuIDs;
integer g_iMenuStride;

string UPMENU = "BACK";

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();

    llRegionSayTo(g_kCollar, API_CHANNEL, llList2Json(JSON_OBJECT, [ "pkt_type", "from_addon", "addon_name", g_sAddon, "iNum", DIALOG, "sMsg", (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, "kID", kMenuID ]));

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [ kID, kMenuID, sName ], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Grabby Post Addon v2.0]";
    list lButtons  = ["Unleash"];

    //llSay(0, "opening menu");
    Dialog(kID, sPrompt, lButtons, ["DISCONNECT", UPMENU], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (iNum<CMD_OWNER || iNum>CMD_WEARER) return;
    if (llSubStringIndex(llToLower(sStr), llToLower(g_sAddon)) && llToLower(sStr) != "menu " + llToLower(g_sAddon)) return;
    if (iNum == CMD_OWNER && llToLower(sStr) == "runaway") {
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
        llListInsertList(packet_data, [ "optin", llDumpList2String(g_lOptedLM, "~") ], -1);
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
integer g_iListener=-1;
key g_kUser=NULL_KEY;

integer g_iLeashed=FALSE;

list g_lVictims = [];
integer g_iCurrentVictim;
DoNextVictim()
{
    g_iCurrentVictim++;
    if(g_iCurrentVictim>=llGetListLength(g_lVictims))
    {
        llWhisper(0, "All potential victims are either leashed, or do not wear zCollar");
        llResetScript();
    }

    g_kUser = (key)llList2String(g_lVictims,g_iCurrentVictim);
    API_CHANNEL = ((integer)("0x"+llGetSubString((string)llDetectedKey(0),0,8)))+0xf6eb - 0xd2;
    g_iListener = llListen(API_CHANNEL, "", "", "");
    Link("online", 0, "", g_kUser);
    llResetTime();
}
default
{
    state_entry()
    {
        llSetTimerEvent(0);
        llWhisper(0, "Grabby post is ready!");
    }
/*
    touch_start(integer iNum)
    {
        if(g_iListener!=-1){
            Link("offline", 0, "", g_kUser);
            llListenRemove(g_iListener);
            llWhisper(0, "Disconnecting from secondlife:///app/agent/"+(string)g_kUser+"/about");
        }
        g_kUser = llDetectedKey(0);
        API_CHANNEL = ((integer)("0x" + llGetSubString((string)llDetectedKey(0), 0, 8))) + 0xf6eb - 0xd2;
        g_iListener = llListen(API_CHANNEL, "", "", "");
        Link("online", 0, "", llDetectedKey(0)); // This is the signal to initiate communication between the addon and the collar
    }
  */
    touch_start(integer t)
    {
        if(g_iListener!=-1)
        {
            llWhisper(0, "Please wait.. in use");
            return;
        }
        llSensor("", "", AGENT, 20, PI);
        g_lVictims=[];

        g_iCurrentVictim = -1;
        llWhisper(0, "Scanning for victims...");
    }

    no_sensor()
    {
        llWhisper(0, "No victims found");
    }

    sensor(integer n)
    {
        integer i=0;
        for(i=0;i<n;i++)
        {
            g_lVictims += llDetectedKey(i);
        }

        DoNextVictim();
        llResetTime();
        llSetTimerEvent(1);
    }
    timer()
    {
        // This is not a standard addon. It expects to connect virtually immediately. If no response in 5 seconds, do next victim
        if(llGetTime()>=5)
        {
            llResetTime();
            DoNextVictim();
        }
    }

    listen(integer channel, string name, key id, string msg){
        //llSay(0, msg);
        string sPacketType = llJsonGetValue(msg, ["pkt_type"]);
        if (sPacketType == "approved" && g_kCollar == NULL_KEY)
        {
            // This signal, indicates the collar has approved the addon and that communication requests will be responded to if the requests are valid collar LMs.
            g_kCollar = id;
            Link("from_addon", LM_SETTING_REQUEST, "ALL", "");
            llSay(0, "Connected");

            llSetTimerEvent(60);
        } else if(sPacketType == "denied" && g_kCollar == NULL_KEY){
            // The collar denied, remove listener
            g_kUser=NULL_KEY;
            llListenRemove(g_iListener);
            g_iListener=-1;
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


                    if(sToken == "leash"){
                        if(sVar == "leashedto"){
                            if(sVal==(string)llGetKey()){
                                // Do not trigger leash!!
                                g_iLeashed=TRUE;
                            }else {
                                g_iLeashed=FALSE;
                            }
                        }
                    }

                    if(sStr == "settings=sent"){
                        if(!g_iLeashed){

                            llSay(0, "Grabbing secondlife:///app/agent/"+(string)llGetOwnerKey(g_kCollar)+"/about's leash");
                            Link("from_addon", CMD_OWNER, "anchor "+(string)llGetKey(), llGetKey());
                            g_iLeashed=0;
                            Link("offline", 0, "", g_kUser);
                            g_kUser=NULL_KEY;
                            g_kCollar=NULL_KEY;
                            DoNextVictim();
                        }
                    }
                }
                else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE)
                {
                    UserCommand(iNum, sStr, kID);

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
                                Link("from_addon", iAuth, "menu Addons", kAv);
                            }
                            else if (sMsg == "Unleash")
                            {
                                Link("from_addon", CMD_OWNER, "unleash", llGetKey());
                                Link("offline", 0, "", g_kUser);
                            }
                            else if (sMsg == "DISCONNECT")
                            {
                                Link("offline", 0, "", g_kUser);
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

