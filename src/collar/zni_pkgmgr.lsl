/*
zni_pkgmgr
This file is a part of zCollar.
Copyright ©2021

: Contributors :

Aria (Tashia Redrose)
    * April 2021        -       Created zni_pkgmgr

et al.


Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/
#include "MasterFile.lsl"

string g_sParentMenu = "Help/About";
string g_sSubMenu = "PackageManager";

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Package Management]\n\n* NOTE: This package manager only permits uninstalling bundles. To install new software, use a installer.";
    list lButtons = [];
    integer i=0;
    integer end = llGetListLength(g_lInstalledBundles);
    for(i=0;i<end;i+=2)
    {
        lButtons += llList2String(g_lInstalledBundles,i+1);
    }
    Dialog(kID, sPrompt, lButtons, [UPMENU, "*ALL*"], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (!(iNum&(C_OWNER|C_WEARER))) return;
    if (llSubStringIndex(llToLower(sStr),llToLower(g_sSubMenu)) && llToLower(sStr) != "menu "+llToLower(g_sSubMenu)) return;
    if (iNum &C_OWNER && llToLower(sStr) == "runaway") {
        g_lOwner=[];
        g_lTrust=[];
        g_lBlock=[];
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
list g_lOwner;
list g_lTrust;
list g_lBlock;
integer g_iLocked=FALSE;

list g_lInstalledBundles;
string g_sPkg;
string g_sPkg_Note;
ScanSoftware()
{
    g_lInstalledBundles=[];
    integer i=0;
    integer end = llGetInventoryNumber(INVENTORY_NOTECARD);
    for(i=0;i<end;i++)
    {
        string sName = llGetInventoryName(INVENTORY_NOTECARD,i);
        if(llSubStringIndex(sName, "BUNDLE_")!=-1)
        {
            list lParts = llParseString2List(sName,["_"],[]);
            g_lInstalledBundles += [sName, llList2String(lParts,2)];
        }
    }
}
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
        if(llGetOwner()!=g_kWearer) llResetScript();
    }
    state_entry()
    {
        g_kWearer = llGetOwner();
        ScanSoftware();
    }
    dataserver(key kID, string sData)
    {
        if(HasDSRequest(kID)!=-1)
        {
            list lMeta = llParseString2List(GetDSMeta(kID), [":"],[]);
            if(llList2String(lMeta, 0)=="num")
            {
                UpdateDSRequest(kID, llGetNotecardLine(llList2String(lMeta,2), 0), "read:0:"+sData+":"+llList2String(lMeta,2)+":"+llList2String(lMeta,1));
            } else if(llList2String(lMeta,0) == "tnum")
            {
                integer iTotal = (integer)llList2String(lMeta,2);
                iTotal+=(integer)sData;
                integer iCur = (integer)llList2String(lMeta,3);
                iCur += 2;
                if(iCur>=llGetListLength(g_lInstalledBundles)){
                    // begin to uninstall starting with first bundle
                    UpdateDSRequest(kID, llGetNotecardLine(llList2String(g_lInstalledBundles,0),0), "tread:0:0:0:"+(string)iTotal+":"+llList2String(lMeta,1));
                    return;
                }

                UpdateDSRequest(kID, llGetNumberOfNotecardLines(llList2String(g_lInstalledBundles,iCur)), "tnum:"+llList2String(lMeta,1)+":"+(string)iTotal+":"+(string)iCur);
            } else if(llList2String(lMeta,0) == "tread")
            {
                if(sData==EOF)
                {
                    integer iCur = (integer)llList2String(lMeta,3);
                    llRemoveInventory(llList2String(g_lInstalledBundles,iCur));
                    iCur += 2;

                    if(iCur >= llGetListLength(g_lInstalledBundles))
                    {
                        // uninstall completed!
                        key kAv = (key)llList2String(lMeta,5);
                        llInstantMessage(kAv,"[100%] zCollar Uninstall Completed");

                        llRemoveInventory(llGetScriptName());
                    }else {

                        UpdateDSRequest(kID, llGetNotecardLine(llList2String(g_lInstalledBundles, iCur), 0), "tread:0:"+llList2String(lMeta,2)+":"+(string)iCur+":"+llList2String(lMeta,4)+":"+llList2String(lMeta,5));
                    }
                }else{
                    integer iLine = (integer)llList2String(lMeta,1);
                    iLine++;
                    integer iProcessed = (integer)llList2String(lMeta,2);
                    iProcessed++;
                    integer iCur = (integer)llList2String(lMeta,3);
                    integer iTotal = (integer)llList2String(lMeta,4);

                    integer iPercent = iProcessed * 100 / iTotal;

                    key kAv = (key)llList2String(lMeta,5);

                    list lLine = llParseString2List(sData,["|"],[]);
                    if(llGetScriptName() == llList2String(lLine,1))
                    {
                        llInstantMessage(kAv, "["+(string)iPercent+"%] "+llGetScriptName()+" not removed yet, will be removed at conclusion of uninstall");
                    }else{
                        llInstantMessage(kAv, "["+(string)iPercent+"%] "+llList2String(lLine,1)+" removed");
                        if(llGetInventoryType(llList2String(lLine,1))!=INVENTORY_NONE)llRemoveInventory(llList2String(lLine,1));
                    }


                    UpdateDSRequest(kID, llGetNotecardLine(llList2String(g_lInstalledBundles, iCur), iLine), "tread:"+(string)iLine+":"+(string)iProcessed+":"+(string)iCur+":"+(string)iTotal+":"+(string)kAv);

                }
            } else if(llList2String(lMeta,0) == "read")
            {
                if(sData == EOF)
                {
                    llInstantMessage((key)llList2String(lMeta,4), "[100%] Uninstallation of bundle completed");
                    llRemoveInventory(llList2String(lMeta,3));
                    DeleteDSReq(kID);
                    ScanSoftware();

                    llMessageLinked(LINK_SET, 0, "menu PackageManager", (key)llList2String(lMeta,4));
                }else {
                    integer iLine = (integer)llList2String(lMeta,1);
                    iLine++;
                    integer iTotal = (integer)llList2String(lMeta,2);
                    integer iPercent = iLine * 100 / iTotal;

                    list lLine = llParseString2List(sData, ["|"],[]);
                    if(llGetScriptName() == llList2String(lLine,1)){
                        llOwnerSay("["+(string)iPercent+"%] Package Manager script not removed - If you wish to delete this script, you must do so manually");
                    } else {
                        llInstantMessage((key)llList2String(lMeta,4), "["+(string)iPercent+"%] Removed Item: "+llList2String(lLine,1));
                        if(llGetInventoryType(llList2String(lLine,1))!=INVENTORY_NONE)
                            llRemoveInventory(llList2String(lLine,1));
                    }

                    UpdateDSRequest(kID, llGetNotecardLine(llList2String(lMeta, 3), iLine), "read:"+(string)iLine+":"+(string)iTotal+":"+llList2String(lMeta,3)+":"+llList2String(lMeta,4));
                }
            }
        }
    }

    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum == COMMAND) {
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = (integer)llList2String(lTmp,0);
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

                integer iRespring = TRUE;

                if(sMenu == "Menu~Main"){
                    if(sMsg == UPMENU) {
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                        iRespring=FALSE;
                    } else if(sMsg == "*ALL*")
                    {

                        // initiate uninstall of all bundles
                        Dialog(kAv, "Are you sure you want to uninstall zCollar?", ["Yes", "No"], [],0,iAuth, "consent~all");
                        iRespring=FALSE;
                    }else {
                        // Initiate uninstallation procedure
                        integer iIndex = llListFindList(g_lInstalledBundles, [sMsg]);
                        if(iIndex==-1)
                        {
                            // Package was not found
                            llMessageLinked(LINK_SET, NOTIFY, "0The package '"+sMsg+"' was not found", kAv);
                        } else {
                            // Package found, begin to uninstall
                            g_sPkg = sMsg;
                            g_sPkg_Note = llList2String(g_lInstalledBundles,iIndex-1);
                            Dialog(kAv, "Are you sure you want to uninstall the package: "+sMsg, ["Yes", "No"], [], 0, iAuth, "consent");
                            iRespring=FALSE;
                        }

                    }


                    if(iRespring)Menu(kAv,iAuth);
                } else if(sMenu == "consent")
                {
                    if(sMsg == "Yes"){
                        llMessageLinked(LINK_SET, NOTIFY, "1Uninstalling package '"+g_sPkg+"'", kAv);
                        UpdateDSRequest(NULL, llGetNumberOfNotecardLines(g_sPkg_Note), "num:"+(string)kAv+":"+g_sPkg_Note);
                    }else if(sMsg == "No")
                    {
                        llMessageLinked(LINK_SET, NOTIFY, "1Uninstall of package: "+g_sPkg+" cancelled", kAv);
                        Menu(kAv,iAuth);
                    }
                } else if(sMenu == "consent~all")
                {
                    if(sMsg == "Yes")
                    {
                        llMessageLinked(LINK_SET, NOTIFY, "1Uninstalling zCollar", kAv);
                        UpdateDSRequest(NULL, llGetNumberOfNotecardLines(llList2String(g_lInstalledBundles, 0)), "tnum:"+(string)kAv+":0:0");
                    }else{
                        llMessageLinked(LINK_SET, NOTIFY, "1Uninstallation of zCollar cancelled", kAv);
                        Menu(kAv,iAuth);
                    }
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


            /* else if(sToken == "auth"){
                if(sVar == "owner"){
                    g_lOwners = llParseString2List(sVal,[","],[]);
                }
            }*/
        } else if(iNum == LM_SETTING_DELETE){
            // This is recieved back from settings when a setting is deleted
            list lSettings = llParseString2List(sStr, ["_"],[]);
        } else if(iNum == REBOOT){
            llResetScript();
        }
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}
