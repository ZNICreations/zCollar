/*
This file is a part of zCollar.
Copyright ©2021

: Contributors :

Aria (Tashia Redrose)
    * April 2021    -       Rebranded under zCollar
    *Jan 2021       -       Created optional app for notification on owner login

et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/
#include "MasterFile.lsl"


string g_sParentMenu = "Apps";
string g_sSubMenu = "Owner Online";



Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}
integer g_iNotifyOwner = 0; // This could get spammy!

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Owner Online Checker App]\n\nSet Interval\t\t- Default (60); Current ("+(string)g_iInterval+")\nNotifChat\t\t- Notification in local chat (private)\nNotifDialog\t\t- Notification in a dialog box\nNotifOwner\t\t- Notification on sub login is sent to the collar owner(s)\n\n\n* Note: This app can be fully controlled by the collar wearer";
    list lButtons = [Checkbox(g_iEnable, "ON"), "Set Interval", Checkbox(g_iTypeLocal, "NotifChat"), Checkbox(g_iTypeDialog, "NotifDialog"), Checkbox(g_iNotifyOwner, "NotifOwner")];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (llSubStringIndex(llToLower(sStr),llToLower(g_sSubMenu)) && llToLower(sStr) != "menu "+llToLower(g_sSubMenu)) return;
    if (iNum & C_OWNER && llToLower(sStr) == "runaway") {
        return;
    }
    if (llToLower(sStr)==llToLower(g_sSubMenu) || llToLower(sStr) == "menu "+llToLower(g_sSubMenu)) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        //integer iWSuccess = 0;
        //string sChangetype = llList2String(llParseString2List(sStr, [" "], []),0);
        //string sChangevalue = llList2String(llParseString2List(sStr, [" "], []),1);
        //string sText;
        /// [prefix] g_sSubMenu sChangetype sChangevalue
    }
}

key g_kWearer;
integer g_iLocked=FALSE;
integer g_iInterval=60;
integer g_iEnable;
integer g_iTypeLocal=1;
integer g_iTypeDialog;

list g_lOwners; // uuid, online, inRegion

UpdateOwner(key ID, integer online)
{
    if(ID == "")return;
    integer index = llListFindList(g_lOwners, [ID]);
    if(index==-1) g_lOwners += [ID, online];
    else {
        integer lastState = (integer)llList2String(g_lOwners,index+1);

        //llSay(0, "UPDATE called ("+(string)lastState+", "+(string)lastRegion+") [secondlife:///app/agent/"+(string)ID+"/about] = ("+(string)online+", "+(string)inRegion+")");
        if(lastState==online){}
        else {
            if(online){
                if(g_iTypeLocal)llMessageLinked(LINK_SET, NOTIFY, "0[Owner Online Alert]  secondlife:///app/agent/"+(string)ID+"/about has logged in", g_kWearer);
                if(g_iTypeDialog)Dialog(g_kWearer, "[Owner Online Checker App]\n\n\nsecondlife:///app/agent/"+(string)ID+"/about has logged in", [],["-exit-"],0,0, "StatusAlert");
            }else {
                if(g_iTypeLocal)llMessageLinked(LINK_SET, NOTIFY, "0[Owner Online Alert]  secondlife:///app/agent/"+(string)ID+"/about has logged out", g_kWearer);
                if(g_iTypeDialog)Dialog(g_kWearer, "[Owner Online Checker App]\n\n\nsecondlife:///app/agent/"+(string)ID+"/about has logged out", [],["-exit-"],0,0, "StatusAlert");
            }
            g_lOwners = llListReplaceList(g_lOwners, [online], index+1, index+1);
        }
    }
    //llSay(0, "UPDATE final list contents: "+llDumpList2String(g_lPita, "~"));
}


integer g_iStartup = TRUE;
default
{
    on_rez(integer iNum){
        if(g_iNotifyOwner){
            llMessageLinked(LINK_SET, NOTIFY_OWNERS, "%WEARERNAME% has logged in, or rezzed the collar", "");
        }
        llResetScript();
    }
    state_entry(){
        llMessageLinked(LINK_SET, ALIVE, llGetScriptName(),"");
    }
    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum == REBOOT){
            if(sStr == "reboot"){
                llResetScript();
            }
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

    timer(){
        if(g_iEnable){
            llSetTimerEvent(g_iInterval);
            UpdateDSRequest(NULL, llRequestAgentData(llList2Key(g_lOwners, 0),DATA_ONLINE), "get_online:0");
        }else{
            llSetTimerEvent(0);
            return;
        }
    }

    dataserver(key kID, string sData)
    {
        if(HasDSRequest(kID)!=-1){
            string meta = GetDSMeta(kID);
            list lTmp = llParseString2List(meta,[":"],[]);
            if(llList2String(lTmp,0)=="get_online"){
                DeleteDSReq(kID);
                integer curIndex = (integer)llList2String(lTmp,1);
                key curAv = llList2Key(g_lOwners,curIndex);
                UpdateOwner(curAv, (integer)sData);
                curIndex+=2;
                if(curIndex>=llGetListLength(g_lOwners)){
                    return;
                }
                UpdateDSRequest(NULL, llRequestAgentData(llList2Key(g_lOwners,curIndex),DATA_ONLINE), "get_online:"+(string)curIndex);
            }
        }
    }

    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum == COMMAND) {
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = llList2Integer(lTmp,0);
            string sCmd = llList2String(lTmp,1);
            if(!(iMask&(C_OWNER|C_WEARER)))return;
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
                integer iRespring=TRUE;
                if(sMenu == "Menu~Main"){
                    if(sMsg == UPMENU) {
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                    }
                    else if(sMsg == Checkbox(g_iEnable, "ON")){
                        g_iEnable=1-g_iEnable;
                        llSetTimerEvent(g_iEnable);
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE, "ownerchecks_enable="+(string)g_iEnable, "");
                    }else if(sMsg == "Set Interval"){
                        Dialog(kAv, "What interval do you want to use for the check timer?\n\nDefault: 60", [],[],0,iAuth, "Menu~Interval");
                        iRespring=FALSE;
                    } else if(sMsg == Checkbox(g_iTypeLocal, "NotifChat")){
                        g_iTypeLocal = 1-g_iTypeLocal;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "ownerchecks_typechat="+(string)g_iTypeLocal, "");
                    } else if(sMsg == Checkbox(g_iTypeDialog, "NotifDialog")){
                        g_iTypeDialog=1-g_iTypeDialog;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "ownerchecks_typedialog="+(string)g_iTypeDialog,"");
                    } else if(sMsg == Checkbox(g_iNotifyOwner, "NotifOwner")){
                        g_iNotifyOwner=1-g_iNotifyOwner;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "ownerchecks_notifowner="+(string)g_iNotifyOwner, "");
                    }

                    if(iRespring)Menu(kAv,iAuth);

                } else if(sMenu == "Menu~Interval"){
                    g_iInterval=(integer)sMsg;
                    llSetTimerEvent(g_iEnable);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "ownerchecks_interval="+(string)g_iInterval, "");
                    Menu(kAv,iAuth);
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

            if(sToken=="auth"){
                if(sVar=="owner"){
                    g_lOwners=[];
                    integer i=0;
                    list lTmpOwner = llParseString2List(sVal, [","],[]);
                    integer x = llGetListLength(lTmpOwner);
                    for(i=0;i<x;i++){
                        if(llList2String(lTmpOwner,i)!=g_kWearer)
                            UpdateOwner((key)llList2String(lTmpOwner, i), FALSE);
                    }
                }
            } else if(sToken == "ownerchecks"){
                if(sVar == "enable"){
                    g_iEnable=(integer)sVal;
                    llSetTimerEvent(g_iEnable);
                } else if(sVar == "interval"){
                    g_iInterval = (integer)sVal;
                } else if(sVar == "typechat"){
                    g_iTypeLocal=(integer)sVal;
                }else if(sVar == "typedialog"){
                    g_iTypeDialog=(integer)sVal;
                } else if(sVar == "notifowner"){
                    g_iNotifyOwner = (integer)sVal;
                }
            }

            if(sStr == "settings=sent")
            {
                llSetTimerEvent(g_iEnable);
            }
        }
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}
