
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
string SERVER = "";


integer TIMEOUT_REGISTER = 30498;
integer TIMEOUT_FIRED = 30499;


list g_lDSRequests;
key NULL=NULL_KEY;
UpdateDSRequest(key orig, key new, string meta){
    if(orig == NULL){
        g_lDSRequests += [new,meta];
    }else {
        integer index = HasDSRequest(orig);
        if(index==-1)return;
        else{
            g_lDSRequests = llListReplaceList(g_lDSRequests, [new,meta], index,index+1);
        }
    }
}

string GetDSMeta(key id){
    integer index=llListFindList(g_lDSRequests,[id]);
    if(index==-1){
        return "N/A";
    }else{
        return llList2String(g_lDSRequests,index+1);
    }
}

integer HasDSRequest(key ID){
    return llListFindList(g_lDSRequests, [ID]);
}

DeleteDSReq(key ID){
    if(HasDSRequest(ID)!=-1)
        g_lDSRequests = llDeleteSubList(g_lDSRequests, HasDSRequest(ID), HasDSRequest(ID)+1);
    else return;
}

//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUSTED = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
//integer CMD_SAFEWORD = 510;
//integer CMD_RELAY_SAFEWORD = 511;

integer NOTIFY = 1002;
integer REBOOT = -1000;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script sends responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from settings
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value

//integer MENUNAME_REQUEST = 3000;
//integer MENUNAME_RESPONSE = 3001;
//integer MENUNAME_REMOVE = 3003;

//integer RLV_CMD = 6000;
//integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.

//integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
//integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
//string UPMENU = "BACK";
//string ALL = "ALL";

Send(string args, string meta){
    UpdateDSRequest(NULL, llHTTPRequest(SERVER+"/Collar_Settings.php", [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], args), meta);
}

integer g_iTotalSettings;
key g_kWearer;
integer g_iSettingsRead;
key g_kSettingsCard;
integer g_iWeldStorage = -99;
FindLeashpointOrLock()
{
    g_iWeldStorage=-99;
    integer i=0;
    integer end = llGetNumberOfPrims();
    for(i=0;i<=end;i++){
        if(llToLower(llGetLinkName(i))=="lock"){
            g_iWeldStorage = i;
            return;
        }else if(llToLower(llGetLinkName(i)) == "leashpoint"){
            g_iWeldStorage = i; // keep going incase we find the lock prim
        }
    }
}

CheckForAndSaveWeld(){
    FindLeashpointOrLock();
    if(g_iWeldStorage==-99)return;
    if(g_iWeldStorage == LINK_ROOT)return;
    /*if(SettingExists("intern_weld") || SettingExists("intern_weldby")){
        integer Welded = (integer)GetSetting("intern_weld");

        // begin
        string sDesc = llList2String(llGetLinkPrimitiveParams(g_iWeldStorage, [PRIM_DESC]),0);


        list lPara = llParseString2List(sDesc, ["~"],[]);

        //llSay(0, "Parameters: "+llList2CSV(lPara));
        if(llListFindList(lPara, ["weld"])==-1){
            if(Welded){
                //
                //if(GetSetting("intern_weldby")=="NOT_FOUND")g_lSettings = SetSetting("intern_weldby", (string)NULL_KEY);
                lPara+=["weld",GetSetting("intern_weldby")];
            }
        }else {
            if(!Welded){
                integer index = llListFindList(lPara, ["weld"]);
                lPara=llDeleteSubList(lPara,index,index+1);
            }else {
                // update the weld flag for weldby
                integer index = llListFindList(lPara,["weld"]);
                lPara=llListReplaceList(lPara,[GetSetting("intern_weldby")],index+1,index+1);
            }
        }

        llSetLinkPrimitiveParams(g_iWeldStorage, [PRIM_DESC, llDumpList2String(lPara,"~")]);
        //llSay(0, "saved weld state as: "+llDumpList2String(lPara,"~") + "("+(string)llStringLength(llDumpList2String(lPara,"~"))+") to prim "+(string)g_iWeldStorage + "("+llGetLinkName(g_iWeldStorage)+")");

    }*/
}

RestoreWeldState(){
    FindLeashpointOrLock();
    if(g_iWeldStorage==-99)return;
    if(g_iWeldStorage == LINK_ROOT)return;


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

DeleteWeldFlag()
{
    FindLeashpointOrLock();
    if(g_iWeldStorage == -99)return;
    if(g_iWeldStorage == LINK_ROOT)return;

    list lPara = llParseString2List(llList2String(llGetLinkPrimitiveParams(g_iWeldStorage, [PRIM_DESC]) , 0), ["~"], []);
    integer iIndex = llListFindList(lPara,["weld"]);


    if(iIndex==-1)return;

    lPara = llDeleteSubList(lPara,iIndex,iIndex+1);

    llSetLinkPrimitiveParams(g_iWeldStorage, [PRIM_DESC, llDumpList2String(lPara,"~")]);
}

string g_sSettings = ".settings";


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
    if(iMask == CMD_OWNER || iMask==CMD_WEARER)return TRUE;
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
            ,[],["=","+"]);
    list l2 = llParseString2List(llDumpList2String(llList2List(lTmp,2,-1),""), ["~"],[]);
    integer iAppendMode = iSetor((llList2String(lTmp,1)=="+"),TRUE,FALSE);

    integer iWeldSetting=FALSE;
    if(~llSubStringIndex(sLine, "weld"))iWeldSetting=TRUE;
    if(!iAppendMode){
        // start setting!
        integer i=0;
        integer end = llGetListLength(l2);

        for(i=0;i<end;i+=2){ // start on first index because l2 is initialized off of the 0 element
            //llOwnerSay(llList2String(lTmp,0)+"_"+llList2String(l2,i)+"="+llList2String(l2,i+1));
            if(llList2String(lTmp,0)=="settings" && llList2String(l2,i)=="nocomma"){
                g_iNoComma=(integer)llList2String(l2,i+1);
            }
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
        }

    }
    if(iWeldSetting) llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "check_weld");
}
list g_lMenuIDs;
integer g_iMenuStride;
default
{
    state_entry()
    {
        if(llGetLinkNumber()==LINK_ROOT || llGetLinkNumber()==0){}else{
            // I didn't feel like doing a bunch of complex logic there, so we're just doing an else case. If we are not in the root prim, delete ourself
            llOwnerSay("Moving oc_settings");
            llRemoveInventory(llGetScriptName());
        }
        g_kWearer = llGetOwner();


        if(llGetInventoryType(g_sSettings)!=INVENTORY_NONE){
            g_iSettingsRead=0;
            g_kSettingsCard = llGetInventoryKey(g_sSettings);
            UpdateDSRequest(NULL, llGetNotecardLine(g_sSettings,0), "read_settings:0");
        }

        Send("type=LIST", "lst");
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
            // nothing here yet
        }
    }

    http_response(key kID, integer iStat, list lMeta, string sBody)
    {
        if(HasDSRequest(kID)!=-1){

            list lDat = llParseStringKeepNulls(sBody, [";;"],[]);
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
                    llMessageLinked(LINK_SET, CMD_OWNER, "reboot --f", "");
                } else if(sType == "RANGE_GET"){
                    list meta = llParseString2List(GetDSMeta(kID), [":"],[]);
                    if(llList2String(meta,0)=="all"){
                        integer lastMin = (integer)llList2String(meta,1);
                        lastMin+=10;
                        // Iterate over the results
                        list lSet = llParseStringKeepNulls(llList2String(lDat, 3), ["~"],[]);
                        integer i=0;
                        integer end = llGetListLength(lSet);
                        for(i=0;i<end;i++)
                        {
                            //
                            list llDat = llParseStringKeepNulls(llList2String(lSet,i), [";"],[]);
                            llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, llList2String(llDat,0)+"_"+llList2String(llDat,1)+"="+llList2String(llDat,2), "");
                        }
                        if(lastMin>=g_iTotalSettings)
                        {
                            // Startup completed
                            llMessageLinked(LINK_SET, NOTIFY, "0Startup Complete", llGetOwner());
                            llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "settings=sent", "");
                        }else{
                            // Request next batch
                            Send("type=ALL&minimum="+(string)lastMin+"&maximum=10", "all:"+(string)lastMin);
                        }
                    }
                } else if(sType == "NB")
                {
                    g_iTotalSettings = (integer)llList2String(lDat,2);
                    if(g_iTotalSettings==0){
                        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "settings=sent", "");
                    }else Send("type=ALL&minimum=0&maximum=10", "all:0");
                }
            }
            // we dont need to update the request here
            DeleteDSReq(kID);
        }
    }

    link_message(integer iSender, integer iNum, string sMsg, key kID)
    {
        if(iNum == LM_SETTING_SAVE)
        {
            list lPar = llParseString2List(sMsg, ["_","="],[]);
            Send("type=PUT&token="+llList2String(lPar,0)+"&var="+llList2String(lPar,1)+"&val="+llList2String(lPar,2), "set");
        } else if(iNum == LM_SETTING_REQUEST)
        {
            // TODO: Add a ALL request handler
            list lPar = llParseString2List(sMsg, ["_"],[]);
            if(sMsg!="ALL")
                Send("type=GET&token="+llList2String(lPar,0)+"&var="+llList2String(lPar,1), "get");
            else
                Send("type=LIST", "list");
                //Send("type=ALL&minimum=0&maximum=10", "all:0");
        } else if(iNum == LM_SETTING_DELETE)
        {
            list lPar = llParseString2List(sMsg, ["_"],[]);
            Send("type=DELETE&token="+llList2String(lPar,0)+"&var="+llList2String(lPar,1), "delete");
        } else if(iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sMsg, kID);
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
                        llMessageLinked(LINK_SET, iAuth, "reboot", kAv);
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
                }

            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == TIMEOUT_FIRED){
            if(sMsg == "check_weld")CheckForAndSaveWeld();
        }
    }
}
