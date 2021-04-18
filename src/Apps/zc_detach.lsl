  
/*
This file is a part of OpenCollar.
Copyright ©2021

: Contributors :

Aria (Tashia Redrose)
    * Dec 2019      - Rewrote Outfits & Reset Script Version to 1.0
    
    
et al.

Licensed under the GPLv2. See LICENSE for full details.

https://github.com/OpenCollarTeam/OpenCollar
*/
#include "MasterFile.lsl"


string g_sParentMenu = "Apps";
string g_sSubMenu = "Detach";
/*
integer bool(integer a){
    if(a)return TRUE;
    else return FALSE;
}
list g_lCheckboxes=["⬜","⬛"];
string Checkbox(integer iValue, string sLabel) {
    return llList2String(g_lCheckboxes, bool(iValue))+" "+sLabel;
}
*/


Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth + "|1", kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}



Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Detach App]";
    
    Dialog(kID, sPrompt, llGetAttachedList(llGetOwner()),  [UPMENU], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (llSubStringIndex(sStr,llToLower(g_sSubMenu)) && sStr != "menu "+g_sSubMenu) return;
    
    if (sStr==g_sSubMenu || sStr == "menu "+g_sSubMenu) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        integer iWSuccess = 0; 
        string sChangetype = llList2String(llParseString2List(sStr, [" "], []),0);
        string sChangevalue = llList2String(llParseString2List(sStr, [" "], []),1);
        string sText;
        
    }
}

key g_kWearer;
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
        llResetScript();
    }
    state_entry()
    {
        //llScriptProfiler(TRUE);
        g_kWearer = llGetOwner();
        //float baseCalc = llPow(2, 0);
        //llSay(0, "Pow 2^0 : "+(string)baseCalc);
        //llSetTimerEvent(1);
    }
/*    timer(){
        llSetText("Free Memory (oc_detach)\n"+(string)llGetFreeMemory()+"\n \n \n \n \n \n \n \n \n \n \n \n", <0,1,1>,1);
    }
*/    
    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum ==COMMAND) {
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = llList2Integer(lTmp,0);
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
                    else{
                        // remove attachment
                        llOwnerSay("@remattach:"+sMsg+"=force");
                        Menu(kAv,iAuth);
                    }
                }
            }
        }else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == REBOOT)llResetScript();
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}
