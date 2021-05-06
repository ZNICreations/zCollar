  
/*
This file is a part of zCollar.
Copyright ©2021


: Contributors :
Aria (tashia redrose)
    * April 2021        -       zni_settings created
    
et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar


*** NOTE: Because this file contains sensitive information, the inworld distributed copy will be no modify.
*/
#include "MasterFile.lsl"

string SERVER = "https://api.zontreck.dev/zni";

list g_lReqs;
SendX(string Req,string method, string meta){
    g_lReqs += [Req, method, meta];
    if(g_iVerbosity>=3)llOwnerSay("Queued Request: "+Req+" ~ "+meta);
    Sends(NULL_KEY);
}
Sends(key kNum){
    if(g_kCurrentReq == kNum){
        DoNextRequest();
    }
    
    if(llGetListLength(g_lReqs)==0)g_kCurrentReq=NULL_KEY;
    //g_lReqs += [llHTTPRequest(URL + llList2String(lTmp,0), [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(llList2List(lTmp,1,-1), "?"))];
}

key g_kCurrentReq = NULL_KEY;
integer DEBUG=FALSE;
DoNextRequest(){
    if(llGetListLength(g_lReqs)==0)return;
    list lTmp = llParseString2List(llList2String(g_lReqs,0),["?"],[]);
    if(g_iVerbosity>=4)llOwnerSay("SENDING REQUEST: "+SERVER+llList2String(g_lReqs,0));
    
    string append = "";
    if(llList2String(g_lReqs,1) == "GET")append = "?"+llDumpList2String(llList2List(lTmp,1,-1),"?");
    
    g_kCurrentReq=llHTTPRequest(SERVER + llList2String(lTmp,0) + append, [HTTP_METHOD, llList2String(g_lReqs,1), HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(llList2List(lTmp,1,-1),"?"));
    UpdateDSRequest(NULL, g_kCurrentReq, llList2String(g_lReqs,2));
}



Send(string args, string meta){
    SendX("/Collar_Settings.php?"+args, "POST", meta);
    //UpdateDSRequest(NULL, llHTTPRequest(SERVER+"/Collar_Settings.php", [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], args), meta);
}

integer g_iTotalSettings;
key g_kWearer;
integer g_iSettingsRead;
key g_kSettingsCard;


RestoreWeldState(){
    // get welded
    list lPara = llParseString2List(llList2String(llGetLinkPrimitiveParams(g_iWeldStorage,[PRIM_DESC]),0),["~"],[]);
    if(llListFindList(lPara,["weld"])!=-1){
        integer index = llListFindList(lPara,["weld"]);
        //g_lSettings = SetSetting("intern_weldby", llList2String(lPara, index+1));
        //g_lSettings = SetSetting("intern_weld","1");
        
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "intern_weld","");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "intern_weldby","");
    }
}


string g_sSettings = "settings";


integer iSetor(integer test,integer a,integer b){
    if(test)return a;
    else return b;
}
Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}


key g_kLoadURL;
string g_sLoadURL;
key g_kLoadURLBy;
integer g_iLoadURLConsented;
UserCommand(integer iNum, string sStr, key kID) {
    string sLower=  llToLower(sStr);
    if(sLower == "print settings" || sLower == "debug settings"){
        /*if(AuthCheck(iNum))PrintAll(kID, llGetSubString(sLower,0,4));
        else Error(kID, sStr);*/
        llMessageLinked(LINK_SET, NOTIFY, "0zCollar Settings:", kID);
        Send("type=LIST", sLower+" "+(string)kID);
    }
    else if(llGetSubString(sLower,0,5) == "reboot")
    {
        if(AuthCheck(iNum)){
            if(g_iRebootConfirmed || sLower == "reboot --f"){
                llMessageLinked(LINK_SET, NOTIFY, "0Rebooting your %DEVICETYPE%...", kID);
                g_iRebootConfirmed=FALSE;
                llMessageLinked(LINK_SET, REBOOT, "reboot", "");
                llSetTimerEvent(2.0);
            } else {
                Dialog(kID, "\n[Settings]\n\nAre you sure you want to reboot the scripts?", ["Yes", "No"], [], 0, iNum, "Reboot");
            }
        } else Error(kID,sStr);
    } else if(sLower == "runaway") {
        if(AuthCheck(iNum)){
            //g_iCurrentIndex=0;
            //llSetTimerEvent(10.0); // schedule refresh
            Send("type=LIST", "lst");
        }
    }
    else if(sLower == "load"){
        if(AuthCheck(iNum)){
            // reload settings - assume there is a .settings notecard
            llMessageLinked(LINK_SET, NOTIFY, "0Loading from notecard...", kID);
            //g_iSettingsRead=0;
            //g_kSettingsRead = llGetNotecardLine(g_sSettings, g_iSettingsRead);
            UpdateDSRequest(NULL, llGetNotecardLine(g_sSettings,0), "read_settings:0");
        } else Error(kID,sStr);
    } else if(llSubStringIndex(sLower, "load url")!=-1){
        // prompt to load from a URL
        // TODO: not yet implemented?
        if(AuthCheck(iNum)){
            // load stuff
            list lTmp = llParseString2List(sStr, [" "],[]);
            string actualURL = llDumpList2String(llList2List(lTmp,2,-1)," ");
            g_sLoadURL = actualURL;
            g_kLoadURLBy = kID;
            g_kLoadURL = llHTTPRequest(actualURL, [],"");
            llMessageLinked(LINK_SET, NOTIFY, "1Loading settings from URL.. Please wait a moment..", kID);
        } else Error(kID,sStr);
    } else if(sLower == "fix"){
        if(AuthCheck(iNum)){
            //g_iCurrentIndex=0;
            //llSetTimerEvent(10);
            Send("type=LIST", "lst");
        }
    }
}
integer AuthCheck(integer iMask){
    if(iMask &(C_OWNER|C_WEARER))return TRUE;
    else return FALSE;
}
Error(key kID, string sCmd){
    llMessageLinked(LINK_SET,NOTIFY,"0%NOACCESS% to command: "+sCmd, kID);
}
/*//--                       Anti-License Text                         --//*/
/*//     Contributed Freely to the Public Domain without limitation.     //*/
/*//   2009 (CC0) [ http://creativecommons.org/publicdomain/zero/1.0 ]   //*/
/*//  Void Singer [ https://wiki.secondlife.com/wiki/User:Void_Singer ]  //*/
/*//--                                                                 --//*/
// Returns a integer that is the positive index of the last vStrTst within vStrSrc
integer uSubStringLastIndex(string vStrSrc,string vStrTst) {
    integer vIdxFnd =
        llStringLength( vStrSrc ) -
        llStringLength( vStrTst ) -
        llStringLength(
            llList2String(
                llParseStringKeepNulls( vStrSrc, (list)vStrTst, [] ),
                0xFFFFFFFF ) //-- (-1)
        );
    return (vIdxFnd | (vIdxFnd >> 31));
}
integer g_iRebootConfirmed=FALSE;
integer g_iNoComma=FALSE;
ProcessSettingLine(string sLine)
{
    // # = comments, at front of line or at end
    // = = sets a setting
    // + = appends a setting (if nocomma = 1, then dont append comma
    if(llGetSubString(sLine,0,0)=="#")return;
    
    list lTmp = llParseString2List(
            llGetSubString(sLine, 0, 
                    iSetor(
                        (uSubStringLastIndex(sLine,"#")
                        >uSubStringLastIndex(sLine,"\"")
                        ), 
                    uSubStringLastIndex(sLine,"#"), -1)
                )
            ,[],["_","+"]);
    list l2 = llParseString2List(llDumpList2String(llList2List(lTmp,2,-1),""), ["~"],[]);
    integer iAppendMode = iSetor((llList2String(lTmp,1)=="+"),TRUE,FALSE);
    
    if(!iAppendMode){
        // start setting!
        integer i=0;
        integer end = llGetListLength(l2);
        
        for(i=0;i<end;i+=2){ // start on first index because l2 is initialized off of the 0 element
            //llOwnerSay(llList2String(lTmp,0)+"_"+llList2String(l2,i)+"="+llList2String(l2,i+1));
            if(llList2String(lTmp,0)=="settings" && llList2String(l2,i)=="nocomma"){
                g_iNoComma=(integer)llList2String(l2,i+1);
            }
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, llList2String(lTmp,0)+"_"+llList2String(l2,i)+"="+llList2String(l2,i+1), "origin");
            //g_lSettings = SetSetting(llList2String(lTmp,0)+"_"+llList2String(l2,i), llList2String(l2,i+1));
        }
    } else {
        // append!!
        integer i=0;
        integer end = llGetListLength(l2);
        for(i=0; i<end;i+=2){
            string sToken = llList2String(lTmp,0)+"_"+llList2String(l2,i);
            /*string sValCur = GetSetting(sToken);
            if(sValCur == "NOT_FOUND")sValCur="";
            if(g_iNoComma)sValCur+= llList2String(l2,i+1);
            else sValCur+=","+llList2String(l2,i+1);
            */
            //llOwnerSay(llList2String(lTmp,0)+"+"+llList2String(l2,i)+"="+llList2String(l2,i+1));
            //g_lSettings = SetSetting(sToken,sValCur);
            
            // TODO: Implement Append Mode in Collar_Settings.php
        }
        
    }
}

integer g_iStartup=TRUE;

string g_sStack;


integer g_iVerbosity = 1;
integer CheckModifyPerm(string sSetting, key kStr)
{
    sSetting = llToLower(sSetting);
    list lTmp = llParseString2List(sSetting,["_", "="],[]);
    if(llList2String(lTmp,0)=="auth") // Protect the auth settings against manual editing via load url or via the settings editor
    {
        if(kStr == "origin")return TRUE;
        else return FALSE;
    }
    if(kStr == "url" && llList2String(lTmp,0) == "intern")return FALSE;
    return TRUE;
}
default
{
    state_entry()
    {
        if(llGetLinkNumber()==LINK_ROOT || llGetLinkNumber()==0){}else{
            // I didn't feel like doing a bunch of complex logic there, so we're just doing an else case. If we are not in the root prim, delete ourself
            llOwnerSay("Moving zni_settings");
            llRemoveInventory(llGetScriptName());
        }
        g_kWearer = llGetOwner();
        
    }
    
    changed(integer iChange){
        if(iChange&CHANGED_INVENTORY){
            if(llGetInventoryType(g_sSettings)!=INVENTORY_NONE){
                if(llGetInventoryKey(g_sSettings)!=g_kSettingsCard){
                    g_iSettingsRead=0;
                    UpdateDSRequest(NULL, llGetNotecardLine(g_sSettings,0),"read_settings:0");
                    g_kSettingsCard = llGetInventoryKey(g_sSettings);
                }
            }
        }
    }
    
    dataserver(key kID, string sData)
    {
        if(HasDSRequest(kID)!=-1)
        {
            list lMeta = llParseString2List(GetDSMeta(kID), [":"], []);
            if(llList2String(lMeta,0) == "read_settings")
            {
                integer iLine = (integer)llList2String(lMeta,1);
                iLine ++;
                if(sData == EOF)
                {
                    // Settings completely read!
                    DeleteDSReq(kID);
                    // begin requesting all settings
                    if(!g_iStartup)
                        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
                    
                    llMessageLinked(LINK_SET, NOTIFY, "0Settings Notecard Imported", g_kWearer);
                }
                else{
                    // Parse the settings line
                    // utilize the save function inside the LMs
                    //llMessageLinked(LINK_SET, LM_SETTING_SAVE, sData, "origin");
                    ProcessSettingLine(sData);
                }
            }
        }
    }
    
    http_response(key kID, integer iStat, list lMeta, string sBody)
    {
        if(HasDSRequest(kID)!=-1){
            
            list lDat = llParseStringKeepNulls(sBody, [";;"],[]);
            g_lReqs = llDeleteSubList(g_lReqs,0,2);
            llSleep(0.5);
            
            if(g_iVerbosity>=3)llOwnerSay("HTTP ("+(string)iStat+")\n\n"+sBody);
            //llOwnerSay(sBody);
            // Intentionally parse for double semi-colon, as some parameters use different delimiters
            string Script = llList2String(lDat,0);
            string sType = llList2String(lDat,1);
            if(Script == "Collar_Settings")
            {
                if(sType == "GET")
                {
                    list lPar = llParseStringKeepNulls(llList2String(lDat,2), [";"],[]);
                    if(llGetListLength(lPar)==2)llMessageLinked(LINK_SET, LM_SETTING_EMPTY, llList2String(lPar,0)+"_"+llList2String(lPar,1), "");
                    else
                        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, llList2String(lPar,0)+"_"+llList2String(lPar,1)+"="+llList2String(lPar,2), "");
                } else if(sType == "RESET"){
                    llMessageLinked(LINK_SET, COMMAND, "1|>reboot --f", "");
                } else if(sType == "RANGE_GET"){
                    list meta = llParseString2List(GetDSMeta(kID), [":"],[]);
                    if(llList2String(meta,0)=="all"){
                        integer lastMin = (integer)llList2String(meta,1);
                        lastMin+=10;
                        // Iterate over the results
                        list lSet = llParseStringKeepNulls(llList2String(lDat, 3), ["~"],[]);
                        integer i=0;
                        integer end = llGetListLength(lSet);
                        list lMode;
                        if(llList2String(meta,2) != "lst")
                        {
                            lMode = llParseString2List(llList2String(meta,2), [" "],[]);
                        }
                        for(i=0;i<end;i++)
                        {
                            // 
                            list llDat = llParseStringKeepNulls(llList2String(lSet,i), [";"],[]);
                            if(llGetListLength(lMode)==0)
                                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, llList2String(llDat,0)+"_"+llList2String(llDat,1)+"="+llList2String(llDat,2), "");
                            else
                            {
                                if(llList2String(llDat,0)=="intern" && llList2String(lMode,0)=="print"){}else{
                                    g_sStack += llList2String(llDat,0)+"_"+llList2String(llDat,1)+"="+llList2String(llDat,2)+"\n";
                                }

                                if(llStringLength(g_sStack)>=900){
                                    llMessageLinked(LINK_SET, NOTIFY, "0.\n"+g_sStack, (key)llList2String(lMode,2));
                                    g_sStack="";
                                }
                            }
                        }
                        if((1+lastMin)>=g_iTotalSettings)
                        {
                            // Startup completed
                            if(g_iStartup){
                                g_iStartup=FALSE;
                                llMessageLinked(LINK_SET, NOTIFY, "0Startup Complete", llGetOwner());
                            }
                            if(llGetListLength(lMode)==0)
                                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "settings=sent", "");
                            else{
                                llMessageLinked(LINK_SET, NOTIFY,"0.\n"+g_sStack, (key)llList2String(lMode,2));
                                g_sStack="";
                                
                                llMessageLinked(LINK_SET, NOTIFY, "0Done Printing Settings", (key)llList2String(lMode,2));
                            }
                            
                        }else{
                            // Request next batch
                            Send("type=ALL&minimum="+(string)lastMin+"&maximum=10", "all:"+(string)lastMin+":"+llList2String(meta,2));
                        }
                    }
                } else if(sType == "NB")
                {
                    g_iTotalSettings = (integer)llList2String(lDat,2);
                    if(g_iTotalSettings==0){
                        if(GetDSMeta(kID)!="lst"){
                            list lMeta = llParseString2List(GetDSMeta(kID), [" "],[]);
                            llMessageLinked(LINK_SET, NOTIFY, "0Done Printing Settings", llList2String(lMeta, 2));
                        }
                        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "settings=sent", "");
                    }else Send("type=ALL&minimum=0&maximum=10", "all:0:"+GetDSMeta(kID));
                } else if(sType == "RESET")
                {
                    llMessageLinked(LINK_SET, NOTIFY, "0Database erased", llGetOwner());
                    llMessageLinked(LINK_SET, NOTIFY_OWNERS, "All collar settings on %WEARERNAME%'s collar have been reset to factory defaults.", "");
                    llMessageLinked(LINK_SET, REBOOT, "", "");
                    llMessageLinked(LINK_SET, REBOOT, "reboot --f", "");
                    llResetScript();
                }
            }
            // we dont need to update the request here
            DeleteDSReq(kID);
            Sends(g_kCurrentReq);
        } else{
            if(kID == g_kLoadURL)
            {
                g_kLoadURL = NULL_KEY;
            
                list lSettings = llParseString2List(sBody, ["\n"],[]);
                integer i=0;
                integer iErrorLevel=0;
                if(lSettings){
                    do{
                        if(CheckModifyPerm(llList2String(lSettings,0), "url") || g_iLoadURLConsented) {
                            // permissions to modify this setting passed the security policy.
                            ProcessSettingLine(llList2String(lSettings,0));
                        } else
                            iErrorLevel++;
                        
                        lSettings = llDeleteSubList(lSettings,0,0);
                        i=llGetListLength(lSettings);
                    } while(i);
                }else llMessageLinked(LINK_SET, NOTIFY, "0Empty URL loaded. No settings changes have been made", g_kLoadURLBy);
                
                if(g_iLoadURLConsented)g_iLoadURLConsented=FALSE;
                if(iErrorLevel > 0){
                    llMessageLinked(LINK_SET, NOTIFY, "1Some settings were not loaded due to the security policy. The wearer has been asked to review the URL and give consent", g_kLoadURLBy);
                    // Ask wearer for consent
                    Dialog(g_kWearer, "[Settings URL Loader]\n\n"+(string)iErrorLevel+" settings were not loaded from "+g_sLoadURL+".\nReason: Security Policy\n\nLoaded by: secondlife:///app/agent/"+(string)g_kLoadURLBy+"/about\n\nPlease review the url before consenting", ["ACCEPT", "DECLINE"], [], 0, C_WEARER, "Consent~LoadURL");
                }
                
                llMessageLinked(LINK_SET, NOTIFY, "1Settings have been loaded", g_kLoadURLBy);
                Send("type=LIST", "lst");
            }
        }
    }
    
    link_message(integer iSender, integer iNum, string sMsg, key kID)
    {
        if(iNum == LM_SETTING_SAVE)
        {
            list lPar = llParseString2List(sMsg, ["_","="],[]);
            
            if(kID != "origin" && (llToLower(llList2String(lPar,0)) == "auth" || llToLower(llList2String(lPar,0))=="intern")){
                // silently deny!
                return;
            }
            
            
            Send("type=PUT&token="+llToLower(llList2String(lPar,0))+"&var="+llToLower(llList2String(lPar,1))+"&val="+llList2String(lPar,2), "set");
        } else if(iNum == STARTUP)
        {
            g_iStartup=TRUE;
            if(llGetInventoryType(g_sSettings)!=INVENTORY_NONE){
                g_iSettingsRead=0;
                g_kSettingsCard = llGetInventoryKey(g_sSettings);
                UpdateDSRequest(NULL, llGetNotecardLine(g_sSettings,0), "read_settings:0");
            }
        
            Send("type=LIST", "lst");
        } else if(iNum == LM_SETTING_REQUEST)
        {
            list lPar = llParseString2List(sMsg, ["_"],[]);
            if(sMsg!="ALL")
                Send("type=GET&token="+llList2String(lPar,0)+"&var="+llList2String(lPar,1), "get");
            else
                Send("type=LIST", "lst");
                //Send("type=ALL&minimum=0&maximum=10", "all:0");
        } else if(iNum == LM_SETTING_DELETE)
        {
            list lPar = llParseString2List(sMsg, ["_"],[]);
            if(kID != "origin" && (llToLower(llList2String(lPar,0)) == "auth" || llToLower(llList2String(lPar,0))=="intern")){
                // silently deny!
                return;
            }
            Send("type=DELETE&token="+llToLower(llList2String(lPar,0))+"&var="+llToLower(llList2String(lPar,1)), "delete");
        } else if(iNum == LM_SETTING_RESET)
        {
            if(((integer)sMsg)&C_OWNER)
            {
                Dialog(kID, "[Database Controller]\n\nAre you sure you want to completely reset the collar memory? This action cannot be undone", ["Yes", "No"],[],0,(integer)sMsg, "resetconsent");
            }else llMessageLinked(LINK_SET, NOTIFY, "0%NOACCESS% to resetting the collar memory", kID);
        } else if(iNum ==COMMAND) {
            list lTmp = llParseString2List(sMsg,["|>"],[]);
            integer iMask =(integer)llList2String(lTmp,0);
            string sTask = llList2String(lTmp,1);
            UserCommand(iMask, sTask, kID);
        }
        else if(iNum == LM_SETTING_RESPONSE)
        {
            list lPar = llParseString2List(sMsg, ["_", "="],[]);
            string sToken = llList2String(lPar,0);
            string sVar = llList2String(lPar,1);
            if(sToken == "global")
            {
                if(sVar == "verbosity")
                {
                    g_iVerbosity = (integer)llList2String(lPar,2);
                }
            }
        }
        //else if(iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        //    llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu+"|"+ g_sSubMenu,"");
        else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sMsg, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                //integer iRespring=TRUE;
                
                if(sMenu == "Reboot"){
                    if(sMsg=="No")return;
                    else if(sMsg=="Yes"){
                        g_iRebootConfirmed=TRUE;
                        llMessageLinked(LINK_SET, COMMAND, (string)iAuth+ "|>reboot", kAv);
                    }
                } else if(sMenu == "Consent~LoadURL")
                {
                    if(sMsg == "DECLINE"){
                        llMessageLinked(LINK_SET, NOTIFY, "0%NOACCESS% to loading auth or intern settings", g_kLoadURLBy);
                    } else if(sMsg == "ACCEPT")
                    {
                        llMessageLinked(LINK_SET, NOTIFY, "1Consented. Reloading URL", g_kLoadURLBy);
                        g_iLoadURLConsented=TRUE;
                        g_kLoadURL = llHTTPRequest(g_sLoadURL, [], "");
                    }
                } else if(sMenu == "resetconsent")
                {
                    if(sMsg == "No")
                    {
                        llMessageLinked(LINK_SET,NOTIFY,"0Reset operation has been cancelled.", kAv);
                    }else{
                        llMessageLinked(LINK_SET, NOTIFY, "1Waiting for database...", kAv);
                        Send("type=RESET", ""); 
                    }
                }
                
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == REBOOT)
        {
            llResetScript();
        }
    }
}
