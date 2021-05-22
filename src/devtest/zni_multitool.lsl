
/*
This file is a part of zCollar.
Copyright ©2021


: Contributors :

Aria (Tashia Redrose)
    * May 2021  -   Created a multitool development helper. This is mostly full of useless commands to the ordinary person.


et al.

Licensed under the GPLv2. See LICENSE for full details.
https://github.com/ZNICreations/zCollar

*/
#include "MasterFile.lsl"

string g_sParentMenu = "Apps";
string g_sSubMenu = "MultiTool";


Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[MultiTool App]\n\n* All available options are by command only!";
    list lButtons = [];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Main");
}

list g_lUsage = ["check/online", "[first] [optional:last]",
"check/name", "uuid",
"check/id", "[first] [optional:last]",
"atob", "[Text...]",
"btoa", "[B64...]",
"rng", "[min] [max]"
];

Usage(key kID, string sPath)
{
    integer iIndex=llListFindList(g_lUsage, [llToLower(sPath)]);
    if(iIndex!= -1)llMessageLinked(LINK_SET, NOTIFY, "0Command Usage: "+sPath+" "+llList2String(g_lUsage, iIndex+1), kID);
}

UsageAll(key kID)
{
    // OK
    integer i=0;
    integer end = llGetListLength(g_lUsage);
    llMessageLinked(LINK_SET,NOTIFY, "0Printing all multitool commands", kID);
    for(i=0;i<end;i+=2)
    {
        string sCommand = llDumpList2String(llParseString2List(llList2String(g_lUsage,i), ["/"],[]), " ");
        llMessageLinked(LINK_SET,NOTIFY,"0Command Usage: "+sCommand+" "+llList2String(g_lUsage,i+1), kID);
    }
}

UserCommand(integer iNum, string sStr, key kID) {
    if(!(iNum&(C_OWNER|C_WEARER)))return; // This example plugin limits menu and command access to owner, trusted, and wearer

    if (llToLower(sStr)==llToLower(g_sSubMenu) || llToLower(sStr) == "menu "+llToLower(g_sSubMenu)) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        //integer iWSuccess = 0; 
        list lArgs = llParseString2List(sStr, [" "], []);
        string sChangetype = llList2String(lArgs,0);
        string sChangevalue = llList2String(lArgs,1);
        string sArg3 = llList2String(lArgs,2);
        string sArg4 = llList2String(lArgs,3);
        //string sText;
        /// [prefix] g_sSubMenu sChangetype sChangevalue
        if(llToLower(sChangetype) == "check")
        {
            if(llToLower(sChangevalue) == "online")
            {
                if(sArg3 == ""){
                    Usage(kID, sChangetype+"/"+sChangevalue);
                } else {
                    if(sArg4!="")
                        UpdateDSRequest(NULL, llRequestUserKey(sArg3+" "+sArg4), "oncheck_name:"+(string)kID);
                    else
                        UpdateDSRequest(NULL, llRequestUserKey(sArg3), "oncheck_name:"+(string)kID);
                }
            } else if(llToLower(sChangevalue) == "name")
            {
                if(sArg3 == "")
                {
                    Usage(kID, sChangetype+"/"+sChangevalue);
                }else{
                    llMessageLinked(LINK_SET, NOTIFY, "0"+SLURL(sArg3), kID);
                }
            } else if(llToLower(sChangevalue) == "id")
            {
                if(sArg3==""){
                    Usage(kID, sChangetype+"/"+sChangevalue);
                }else{
                    if(sArg4 != "")
                        UpdateDSRequest(NULL, llRequestUserKey(sArg3+" "+sArg4), "oncheck_id:"+(string)kID);
                    else
                        UpdateDSRequest(NULL, llRequestUserKey(sArg3), "oncheck_id:"+(string)kID);
                }
            }
        } else if(llToLower(sChangetype) == "help")
        {
            if(llToLower(sChangevalue) == "multitool")
            {
                UsageAll(kID);
            }
        } else if(llToLower(sChangetype) == "atob"){
            if(sChangevalue == "")Usage(kID, "atob");
            else
                llMessageLinked(LINK_SET,NOTIFY, "0"+llStringToBase64(llDumpList2String(llList2List(lArgs,1,-1), " ")), kID);
        } else if(llToLower(sChangetype) == "btoa"){
            if(sChangevalue=="")Usage(kID, "btoa");
            else
                llMessageLinked(LINK_SET, NOTIFY, "0"+llBase64ToString(llDumpList2String(llList2List(lArgs,1,-1), " ")), kID);
        } else if(llToLower(sChangetype) == "rng")
        {
            if(sChangevalue == "")Usage(kID, "rng");
            else{
                integer min = llRound((float)sChangevalue);
                integer max = llRound((float)sArg3);
                integer result = 0;
                
                do{
                    result = min+llRound(llFrand(max));
                }
                while( (result<=min) || (result>=max) );
                
                llMessageLinked(LINK_SET, NOTIFY, "0RNG Result : "+(string)result, kID);
            }
        }
        
    }
}

key g_kWearer;
list g_lOwner;
list g_lTrust;
list g_lBlock;
integer g_iLocked=FALSE;

default
{
    on_rez(integer iNum){
        llResetScript();
    }
    state_entry(){
        llMessageLinked(LINK_SET, ALIVE, llGetScriptName(),"");
    }
    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum == REBOOT){
            llResetScript();
            
        } else if(iNum == READY){
            llMessageLinked(LINK_SET, ALIVE, llGetScriptName(), "");
        } else if(iNum == STARTUP){
            state active;
        }
    }
}
state active
{
    on_rez(integer t){
        if(llGetOwner()!=g_kWearer) llResetScript();
    }
    state_entry()
    {
        g_kWearer = llGetOwner();
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "global_locked","");
    }
    dataserver(key kReq, string sData)
    {
        if(HasDSRequest(kReq) != -1)
        {
            list lMeta = llParseString2List(GetDSMeta(kReq), [":"],[]);
            DeleteDSReq(kReq);
            if(llList2String(lMeta,0) == "oncheck_name")
            {
                UpdateDSRequest(NULL, llRequestAgentData((key)sData, DATA_ONLINE), "oncheck:"+llList2String(lMeta,1)+":"+sData);
            }else if(llList2String(lMeta,0) == "oncheck")
            {
                llMessageLinked(LINK_SET, NOTIFY, "0"+SLURL(llList2String(lMeta,2))+" is "+setor((integer)sData, "online", "offline"), (key)llList2String(lMeta,1));
            } else if(llList2String(lMeta,0) == "oncheck_id"){
                llMessageLinked(LINK_SET, NOTIFY, "0"+SLURL(sData)+" = "+sData, llList2String(lMeta,1));
            }
        }
    }
    
    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum == COMMAND) {
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = llList2Integer(lTmp,0);
            if(!(iMask&(C_OWNER|C_WEARER)))return;
            string sCmd = llList2String(lTmp,1);
            UserCommand(iMask, sCmd, kID);
        }
        else if(iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu+"|"+ g_sSubMenu,"");
        else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                
                if(sMenu == "Menu~Main"){
                    if(sMsg == UPMENU) llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == LM_SETTING_RESPONSE){
            // Detect here the Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);
            string sToken = llList2String(lSettings,0);
            string sVar = llList2String(lSettings,1);
            string sVal = llList2String(lSettings,2);
            
        }
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}
