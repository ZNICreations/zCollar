/*
This file is a part of zCollar.
Copyright 2021

: Contributors :

Aria (Tashia Redrose)
    * March 2021         - Created zc_update_shim

et al.


Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/
#include "MasterFile.lsl"


string GetSetting(string sToken) {
    integer i = llListFindList(g_lSettings, [llToLower(sToken)]);
    if(i == -1)return "NOT_FOUND";
    return llList2String(g_lSettings, i + 1);
}

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}
DelSetting(string sToken) { // we'll only ever delete user settings
    sToken = llToLower(sToken);
    integer i = llGetListLength(g_lSettings) - 1;
    if (SplitToken(sToken, 1) == "all") {
        sToken = SplitToken(sToken, 0);
      //  string sVar;
        for (; ~i; i -= 2) {
            if (SplitToken(llList2String(g_lSettings, i - 1), 0) == sToken)
                g_lSettings = llDeleteSubList(g_lSettings, i - 1, i);
        }
        return;
    }
    i = llListFindList(g_lSettings, [sToken]);
    if (~i) g_lSettings = llDeleteSubList(g_lSettings, i, i + 1);
}


// Get Group or Token, 0=Group, 1=Token
string SplitToken(string sIn, integer iSlot) {
    integer i = llSubStringIndex(sIn, "_");
    if (!iSlot) return llGetSubString(sIn, 0, i - 1);
    return llGetSubString(sIn, i + 1, -1);
}

// To add new entries at the end of Groupings
integer GroupIndex(string sToken) {
    sToken = llToLower(sToken);
    string sGroup = SplitToken(sToken, 0);
    integer i = llGetListLength(g_lSettings) - 1;
    // start from the end to find last instance, +2 to get behind the value
    for (; ~i ; i -= 2) {
        if (SplitToken(llList2String(g_lSettings, i - 1), 0) == sGroup) return i + 1;
    }
    return -1;
}

integer SettingExists(string sToken) {
    sToken = llToLower(sToken);
    if (~llListFindList(g_lSettings, [sToken])) return TRUE;
    return FALSE;
}

list SetSetting(string sToken, string sValue) {
    sToken = llToLower(sToken);
    integer idx = llListFindList(g_lSettings, [sToken]);
    if (~idx) return llListReplaceList(g_lSettings, [sValue], idx + 1, idx + 1);
    idx = GroupIndex(sToken);
    if (~idx) return llListInsertList(g_lSettings, [sToken, sValue], idx);
    return g_lSettings + [sToken, sValue];
}

list g_lSettings;
integer g_iPass=0;
integer g_iReady;
integer SECURE; // The secure channel
integer UPDATER_CHANNEL = -7483213;
integer RELAY_CHANNEL = -7483212;
integer g_iRelayActive;

list g_lLinkedScripts = [
    "oc_auth",
    "oc_anim",
    "oc_rlvsys",
    "oc_dialog",
    "oc_settings"
    ];

integer g_iRequiredPhase=FALSE;
CheckLinkedScripts()
{
    integer i=0;
    integer end = llGetListLength(g_lLinkedScripts);
    for(i=0;i<end;i++){
        llMessageLinked(LINK_ALL_OTHERS, LOADPIN, llList2String(g_lLinkedScripts,i), "");
    }
}


string InstallerBox(integer iMode, string sLabel)
{
    string sBox;
    if(iMode==1)sBox = "▣";
    else if(iMode==0)sBox = "□";
    else if(iMode == 2)sBox = "∅";
    else if(iMode == 3)sBox = "⊕";
    
    return sBox+" "+sLabel;
}
list g_lPkgs;
integer g_iLastPage;
key g_kLastAv;

Prompt(key kAv, integer iPage)
{
    g_kLastAv = kAv;
    g_iLastPage=iPage;
    list lButtons = [];
    integer i=0;
    integer end = llGetListLength(g_lPkgs);
    for(i=0;i<end;i+=3)
    {
        lButtons += InstallerBox((integer)llList2String(g_lPkgs,i+2), llList2String(g_lPkgs,i+1));
    }
    
    Dialog(kAv, "What packages would you like to install, or remove?\n\n* Note: Required and deprecated packages cannot be scheduled for uninstallation. If you wish to fully uninstall zCollar, please see the PackageManager in help/about.", lButtons, ["CONFIRM"], iPage, C_OWNER, "prompt~pkgs");
}

integer IndexOfBundle(string InstallBox)
{
    integer i=0;
    integer end = llGetListLength(g_lPkgs);
    for(i=0;i<end;i+=3)
    {
        string Inst = InstallerBox((integer)llList2String(g_lPkgs,i+2), llList2String(g_lPkgs,i+1));
        if(Inst==InstallBox)return i;
    }
    
    return -1;
}

integer HasPackages()
{
    integer i=0;
    integer end = llGetInventoryNumber(INVENTORY_NOTECARD);
    for(i=0;i<end;i++)
    {
        string name = llGetInventoryName(INVENTORY_NOTECARD,i);
        if(llGetSubString(name,0,2)=="PKG")return TRUE;
    }
    
    llOwnerSay("No packages found, you will be shown the default installation options");
    return FALSE;
}

AugmentPackages()
{
    integer i=0;
    integer end = llGetListLength(g_lPkgs);
    if(!HasPackages())return;
    
    for(i=0;i<end;i+=3)
    {
        if(llList2Integer(g_lPkgs,i+2)<=1){
            // inventory iteration
            integer x=0;
            integer xend = llGetInventoryNumber(INVENTORY_NOTECARD);
            g_lPkgs = llListReplaceList(g_lPkgs,[FALSE],i+2,i+2);
            //llOwnerSay("On package: "+llList2String(g_lPkgs,i+1));
            
            for(x=0;x<xend;x++)
            {
                if(llList2String(g_lPkgs,i) == llGetInventoryName(INVENTORY_NOTECARD, x)){
                    g_lPkgs = llListReplaceList(g_lPkgs,[TRUE],i+2,i+2);
                    //llOwnerSay("Package "+llList2String(g_lPkgs,i+1)+" is installed, checking the checkbox");
                }
            }
        }
    }
}
default
{
    state_entry()
    {
        SECURE = llRound(llFrand(8383288));
        llListen(SECURE, "", "", "");
        
        if(llGetInventoryType("oc_dialog") != INVENTORY_NONE)
        {
            llRemoveInventory("oc_dialog"); // forced deprecation of OpenCollar dialog
        }
        
        list lAssertOFF = ["zc_states", "zc_core", "zc_api"];
        integer i=0;
        integer end = llGetListLength(lAssertOFF);
        for(i=0;i<end;i++)
        {
            if(llGetInventoryType(llList2String(lAssertOFF, i))==INVENTORY_SCRIPT)llSetScriptState(llList2String(lAssertOFF, i), FALSE);
        }
        
        //llWhisper(0, "Update Shim is now active. Requesting all settings");
        //llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
        llSetTimerEvent(10);
        
        llSleep(3);
        llMessageLinked(LINK_SET, -57,"","");
        //llMessageLinked(LINK_SET, UPDATER, "update_active", "");
        g_iRelayActive = llGetStartParameter();
        
        
        if(!g_iRelayActive)
            llSay(UPDATER_CHANNEL, "pkg_get|"+(string)SECURE);
        else
            llSay(RELAY_CHANNEL, "wait_prepare|"+(string)SECURE);
    }
    timer()
    {
        if(llGetTime()>=10 && g_iPass!=3 && !g_iReady){
            //g_iPass++;
            llOwnerSay("Please be sure you configure the package preferences.");
            llResetTime();
            //Prompt(g_kLastAv,g_iLastPage);
            //llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
        } else if(llGetTime()>=10 && g_iPass>=3 && !g_iReady)
        {
            llSetTimerEvent(0);
            g_iReady=TRUE;
            llMessageLinked(LINK_SET, UPDATER, "update_active", "");
            if(!g_iRelayActive)
                llSay(UPDATER_CHANNEL, "reallyready|"+(string)SECURE);
            else
                llSay(RELAY_CHANNEL, "reallyready|"+(string)SECURE);
        }
    }
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //llSay(0, "COLLAR LINK MESSAGE: "+llDumpList2String([iNum,sStr,kID], " ~ "));
        if(iNum == LOADPIN)
        {
            list lTmp = llParseString2List(sStr, ["@"],[]);
            llRemoteLoadScriptPin(kID, "zc_linkprim_hammer", (integer)llList2String(lTmp,0), TRUE, 825);
        }else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        }
        else if(iNum == DIALOG_RESPONSE){
        
            list lMenuParams = llParseString2List(sStr, ["|"],[]);
            
            
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                //list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iPage = llList2Integer(lMenuParams,2);
                integer iAuth = llList2Integer(lMenuParams,3);
                
                integer iRespring=TRUE;
                
                //llSay(0, sMenu);
                if(sMenu == "prompt~pkgs"){
                    integer indexOfBundles = IndexOfBundle(sMsg);
                    if(indexOfBundles != -1)
                    {
                        integer iPackageMode = (integer)llList2String(g_lPkgs,indexOfBundles+2);
                        if(iPackageMode>1){
                            llMessageLinked(LINK_SET,1002, "0REQUIRED or DEPRECATED bundles MAY NOT be changed for installation. To uninstall zCollar, please see the Help/About menu for the PackageManager", kAv);
                        }else{
                            iPackageMode=1-iPackageMode;
                            g_lPkgs = llListReplaceList(g_lPkgs, [iPackageMode], indexOfBundles+2,indexOfBundles+2);
                        }
                    } else{
                        if(sMsg == "CONFIRM")
                        {
                            
                            integer i=0;
                            integer end = llGetInventoryNumber(INVENTORY_NOTECARD);
                            for(i=0;i<end;i++)
                            {
                                string name = llGetInventoryName(INVENTORY_NOTECARD,i);
                                if(llSubStringIndex(name,"BUNDLE_")!=-1 || llSubStringIndex(name,"PKG_")!=-1)
                                {
                                    llRemoveInventory(name); // Remove the bundles from the collar to prevent duplicates
                                    i=-1;
                                    end=llGetInventoryNumber(INVENTORY_NOTECARD);
                                }
                            }
                            iRespring=FALSE;
                            llMessageLinked(LINK_SET,1002, "0Please Stand By... Confirming selection!", kAv);
                            // DO MAGIC TO SEND THE PACKAGE LIST, THEN START UPDATE
                            
                            if(g_iRelayActive)llSay(RELAY_CHANNEL, "pkg_set|"+llDumpList2String(g_lPkgs,"~"));
                            else
                                llSay(UPDATER_CHANNEL, "pkg_set|"+llDumpList2String(g_lPkgs,"~"));
                            llResetTime();
                            g_iPass=3;
                        }
                    }
                    if(iRespring)Prompt(kAv, iPage);
                }
            }
        }
    }
    listen(integer c,string n,key i,string m)
    {
        if(c == SECURE)
        {
            //llSay(0, "MESSAGE ON SECURE SHIM CHANNEL: "+m);
            list lCmd = llParseString2List(m,["|"],[]);
            if(llList2String(lCmd,0) == "DONE")
            {
                llOwnerSay("Installation is now finishing");
                //llSay(0, "Installation done signal received!");
                //llSay(0, "Restoring settings, then removing shim");
                llResetOtherScript("zni_settings");
                llResetOtherScript("zc_states");
                list lAssertOFF = ["zc_states", "zc_core", "zc_api"];
                integer ix=0;
                integer end = llGetListLength(lAssertOFF);
                for(ix=0;ix<end;ix++)
                {
                    if(llGetInventoryType(llList2String(lAssertOFF, ix))==INVENTORY_SCRIPT)llSetScriptState(llList2String(lAssertOFF, ix), TRUE);
                }
                llSleep(15);
                llMessageLinked(LINK_SET,REBOOT,"","");
                llSetRemoteScriptAccessPin(0);
                
                llOwnerSay("Installation Completed!");
                llRemoveInventory(llGetScriptName());
            } else if(llList2String(lCmd,0)=="pkg_reply")
            {
                g_lPkgs = llParseString2List(llList2String(lCmd,1), ["~"],[]);
                AugmentPackages();
                
                Prompt(llGetOwner(),0);
            } else if(llList2String(lCmd,0)=="PREP_DONE")
            {
                llSleep(2);
                llMessageLinked(LINK_SET, REBOOT, "", ""); // Prevent the update jail from locking up oc_dialog
                llSleep(1);
                llMessageLinked(LINK_SET,STARTUP,"","");
                llSleep(3);
                llMessageLinked(LINK_SET, LOADPIN , "oc_dialog","");
                llSleep(2);
                llRegionSayTo(i,RELAY_CHANNEL,"pkg_get");
            } else {
                //llSay(0, "Unimplemented updater command: "+m);
                list lOpts = llParseString2List(m,["|"],[]);
                string sOption = llList2String(lOpts,0);
                string sName = llList2String(lOpts,1);
                key kNameID = (key)llList2String(lOpts,2);
                string sBundleType = llList2String(lOpts,3);
                key kDSID = (key)llList2String(lOpts,4);
                integer iDSLine = (integer)llList2String(lOpts,5);
                
                integer bItemMatches = TRUE;
                if(llGetInventoryType(sName)==INVENTORY_NONE || llGetInventoryKey(sName)!=kNameID)bItemMatches=FALSE;
                string sResponse = "SKIP"; // Default command when the option is not yet implemented
                @recheck;
                if(sBundleType == "REQUIRED")
                {
                    g_iRequiredPhase=TRUE;
                    if(sOption == "ITEM")
                    {
                        if(!bItemMatches){
                            if(llGetInventoryType(sName)!=INVENTORY_NONE)
                                llRemoveInventory(sName);
                            sResponse="GIVE";
                        }
                    } else if(sOption == "SCRIPT")
                    {
                        if(!bItemMatches){
                            sResponse="INSTALL";
                        }
                    }
                    else if(sOption == "STOPPEDSCRIPT")
                    {
                        if(!bItemMatches)sResponse="INSTALLSTOPPED";
                    } else {
                        //llWhisper(0, "Unrecognized updater signal for required bundle: "+sOption+"|"+sName);
                    }
                } else if(sBundleType == "DEPRECATED")
                {
                    if(g_iRequiredPhase){
                        g_iRequiredPhase=FALSE;
                        CheckLinkedScripts();
                    }
                    if(sOption == "LIKE"){
                        // special handling
                        integer X = 0;
                        integer X_end = llGetInventoryNumber(INVENTORY_ALL);
                        for(X=0;X<X_end;X++)
                        {
                            string sTmpName = llGetInventoryName(INVENTORY_ALL,X);
                            if(llSubStringIndex(sTmpName,sName)!=-1){
                                llRemoveInventory(sTmpName);
                                X=-1;
                                X_end=llGetInventoryNumber(INVENTORY_ALL);
                            }
                        }
                    }else{
                        if(llGetInventoryType(sName)!=INVENTORY_NONE)llRemoveInventory(sName);
                    }
                } else if(sBundleType == "OPTIONAL")
                {
                    // if item does not match, and exists in inventory, update it without a prompt.
                    // if item does not exist or is the same as the updater version, ask the user
                    if(!bItemMatches && llGetInventoryType(sName)!=INVENTORY_NONE)
                    {
                        sBundleType = "REQUIRED";
                        jump recheck;
                    } else {
                        sResponse="PROMPT";
                        if(llGetInventoryType(sName)==INVENTORY_NONE)sResponse+="_INSTALL";
                        else sResponse+="_REMOVE";
                    }
                }
                
                llRegionSayTo(i, SECURE, llDumpList2String([sResponse, sName, kDSID, iDSLine], "|"));
            }
        }
    }
}
