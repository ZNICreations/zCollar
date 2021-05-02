    
/*
This file is a part of zCollar.
Copyright ©2021


: Contributors :

Aria (Tashia Redrose)
    * April 2021    -       Changed License Terms
    *June 2020       -       Created oc_api
      * This implements some auth features, and acts as a API Bridge for addons and plugins
Felkami (Caraway Ohmai)
    *Dec 2020        -       Fix: 457Switched optin from searching by string to list
    
    
et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/ZNICreations/zCollar

*/
#include "MasterFile.lsl"
list g_lOwner;
list g_lTrust;
list g_lBlock;


integer g_iMode;
string g_sSafeword = "RED";
integer g_iSafewordDisable=FALSE;
integer ACTION_ADD = 1;
integer ACTION_REM = 2;
integer ACTION_SCANNER = 4;
integer ACTION_OWNER = 8;
integer ACTION_TRUST = 16;
integer ACTION_BLOCK = 32;

//integer g_iLastGranted;
//key g_kLastGranted;
//string g_sLastGranted;



key g_kGroup=NULL_KEY;
key g_kWearer;
key g_kTry;
integer g_iCurrentAuth;
key g_kMenuUser;


integer g_iPublic;
string g_sPrefix;
integer g_iChannel=1;

PrintAccess(key kID){
    string sFinal = "\n \nAccess List:\nOwners:";
    integer i=0;
    integer end = llGetListLength(g_lOwner);
    for(i=0;i<end;i++){
        sFinal += "\n   "+SLURL(llList2String(g_lOwner,i));
    }
    end=llGetListLength(g_lTrust);
    sFinal+="\nTrusted:";
    for(i=0;i<end;i++){
        sFinal+="\n   "+SLURL(llList2String(g_lTrust,i));
    }
    end = llGetListLength(g_lBlock);
    sFinal += "\nBlock:";
    for(i=0;i<end;i++){
        sFinal += "\n   "+SLURL(llList2String(g_lBlock,i));
    }
    sFinal+="\n";
    if(llGetListLength(g_lOwner)==0 || llListFindList(g_lOwner, [(string)g_kWearer])!=-1)sFinal+="\n* Wearer is unowned or owns themselves.\nThe wearer has owner access";
    
    sFinal += "\nPublic: "+tf(g_iPublic);
    if(g_kGroup != NULL_KEY) sFinal+="\nGroup: secondlife:///app/group/"+(string)g_kGroup+"/about";
    
    if(!g_iRunaway)sFinal += "\n\n* RUNAWAY IS DISABLED *";
    llMessageLinked(LINK_SET,NOTIFY, "0"+sFinal,kID);
    //llSay(0, sFinal);
}

list g_lActiveListeners;
DoListeners(){
    integer i=0;
    integer end = llGetListLength(g_lActiveListeners);
    for(i=0;i<end;i++){
        llListenRemove(llList2Integer(g_lActiveListeners, i));
    }
    
    g_lActiveListeners = [llListen(g_iChannel, "","",""), llListen(0,"","",""),  llListen(g_iInterfaceChannel, "", "", "")];
    
}
integer g_iRunaway=TRUE;
RunawayMenu(key kID, integer iAuth){
    if(iAuth &(C_OWNER|C_WEARER)){
        string sPrompt = "\n[Runaway]\n\nAre you sure you want to runaway from all owners?\n\n* This action will reset your owners list, trusted list, and your blocked avatars list.";
        list lButtons = ["Yes", "No"];
        
        if(iAuth & C_OWNER){
            sPrompt+="\n\nAs the owner you have the abliity to disable or enable runaway.";
            if(g_iRunaway)lButtons+=["Disable"];
            else lButtons += ["Enable"];
        } else if(iAuth & C_WEARER){
            if(g_iRunaway){
                sPrompt += "\n\nAs the wearer, you can choose to disable your ability to runaway, this action cannot be reversed by you";
                lButtons += ["Disable"];
            }
        }
        Dialog(kID, sPrompt, lButtons, [], 0, iAuth, "RunawayMenu");
    } else {
        llMessageLinked(LINK_SET,NOTIFY,"0%NOACCESS% to runaway, or the runaway settings menu", kID);
        //llMessageLinked(LINK_SET,iAuth,"menu Access", kID);
    }
}

WearerConfirmListUpdate(key kID, string sReason)
{
    //key g_kAdder = g_kMenuUser;
    //g_kMenuUser=kID;
    // This should only be triggered if the wearer is being affected by a sensitive action
    Dialog(g_kWearer, "\n[Access]\n\nsecondlife:///app/agent/"+(string)kID+"/about wants change your access level.\n\nChange that will occur: "+sReason+"\n\nYou may grant or deny this action.", [], ["Allow", "Disallow"], 0, C_WEARER, "WearerConfirmation");
}

integer g_iGrantedConsent=FALSE;
integer g_iRunawayMode = -1;
UpdateLists(key kID, key kIssuer){
    //llOwnerSay(llDumpList2String([kID, kIssuer, g_kMenuUser, g_iMode, g_iGrantedConsent], ", "));
    integer iMode = g_iMode;
    if(iMode&ACTION_ADD){
        if(iMode&ACTION_OWNER){
            if(llListFindList(g_lOwner, [(string)kID])==-1){
                g_lOwner+=kID;
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been added as owner", kIssuer);
                llMessageLinked(LINK_SET, NOTIFY, "0You are now a owner on this collar", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_owner="+llDumpList2String(g_lOwner,","), "origin");
                g_iMode = ACTION_REM | ACTION_TRUST | ACTION_BLOCK;
                UpdateLists(kID, kIssuer);
            }
        }
        if(iMode & ACTION_TRUST){
            if(llListFindList(g_lTrust, [(string)kID])==-1){
                if(g_iCurrentAuth&C_WEARER && !(g_iCurrentAuth&C_OWNER)){
                    llMessageLinked(LINK_SET, NOTIFY_OWNERS, SLURL(kID)+" has been added to the trusted list by the collar wearer.", "");
                }
                g_lTrust+=kID;
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been added to the trusted user list", kIssuer);
                llMessageLinked(LINK_SET, NOTIFY, "0You are now a trusted user on this collar", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_trust="+llDumpList2String(g_lTrust, ","), "origin");
                g_iMode = ACTION_REM | ACTION_OWNER | ACTION_BLOCK;
                UpdateLists(kID, kIssuer);
            }
        }
        if(iMode & ACTION_BLOCK){
            if(llListFindList(g_lBlock, [(string)kID])==-1){
                if(kID != g_kWearer || g_iGrantedConsent || kIssuer==g_kWearer){
                    g_lBlock+=kID;
                    llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been blocked", kIssuer);
                    llMessageLinked(LINK_SET, NOTIFY, "0Your access to this collar is now blocked", kID);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_block="+llDumpList2String(g_lBlock,","),"origin");
                    g_iMode=ACTION_REM|ACTION_OWNER|ACTION_TRUST;
                    UpdateLists(kID, kIssuer);
                    g_iGrantedConsent=FALSE;
                } else if(kID==g_kWearer && !g_iGrantedConsent){
                    WearerConfirmListUpdate(kIssuer, "Block access entirely");
                }
            }
        }
    } else if(iMode&ACTION_REM){
        if(iMode&ACTION_OWNER){
            if(llListFindList(g_lOwner, [(string)kID])!=-1){
                if(kID!=g_kWearer || g_iGrantedConsent || kIssuer==g_kWearer){
                    integer iPos = llListFindList(g_lOwner, [(string)kID]);
                    g_lOwner = llDeleteSubList(g_lOwner, iPos, iPos);
                    llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the owner role", kIssuer);
                    llMessageLinked(LINK_SET, NOTIFY, "0You have been removed from %WEARERNAME%'s collar", kID);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_owner="+llDumpList2String(g_lOwner,","), "origin");
                    g_iGrantedConsent=FALSE;
                } else if(kID == g_kWearer && !g_iGrantedConsent){
                    WearerConfirmListUpdate(kIssuer, "Removal of self ownership");
                }
            }
        } 
        if(iMode&ACTION_TRUST){
            if(llListFindList(g_lTrust, [(string)kID])!=-1){
                if(kID != g_kWearer || g_iGrantedConsent || kIssuer==g_kWearer){
                    if(g_iCurrentAuth&C_WEARER && !(g_iCurrentAuth&C_OWNER)){
                        llMessageLinked(LINK_SET, NOTIFY_OWNERS, SLURL(kID)+" has been removed from the trusted list by the collar wearer.", "");
                    }
                    integer iPos = llListFindList(g_lTrust, [(string)kID]);
                    g_lTrust = llDeleteSubList(g_lTrust, iPos, iPos);
                    llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the trusted role", kIssuer);
                    llMessageLinked(LINK_SET, NOTIFY, "0You have been removed from %WEARERNAME%'s collar", kID);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_trust="+llDumpList2String(g_lTrust, ","),"origin");
                    g_iGrantedConsent=FALSE;
                } else if(kID == g_kWearer && !g_iGrantedConsent){
                    WearerConfirmListUpdate(kIssuer, "Removal from Trusted List");
                }
            }
        }
        if(iMode & ACTION_BLOCK){ // no need to do a confirmation to the wearer if they become unblocked
            if(llListFindList(g_lBlock, [(string)kID])!=-1){
                integer iPos = llListFindList(g_lBlock, [(string)kID]);
                g_lBlock = llDeleteSubList(g_lBlock, iPos, iPos);
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the blocked list", kIssuer);
                llMessageLinked(LINK_SET, NOTIFY, "0You have been removed from %WEARERNAME%'s collar blacklist", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_block="+llDumpList2String(g_lBlock,","),"origin");
            }
        }
    }
}
key g_kPendingSupport;
UserCommand(integer iAuth, string sCmd, key kID){
    if(sCmd == "getauth"){
        llMessageLinked(LINK_SET, NOTIFY, "0Your access level is: "+AuthMask2Str(iAuth)+" ("+(string)iAuth+")", kID);
        return;
    } else if(sCmd == "debug" || sCmd == "versions"){
        // here's where the debug or versions commands will ask consent, then trigger
    } else if(sCmd == "help"){
        if(iAuth & (C_OWNER|C_TRUSTED|C_WEARER|C_GROUP|C_PUBLIC) ){
            llGiveInventory(kID, "zCollar_Help");
            llSleep(2);
            llLoadURL(kID, "Want to open our website for further help?", "https://zontreck.dev");
        }
    }
    if((llToLower(sCmd) == "menu runaway" || llToLower(sCmd) == "runaway") && g_iRunawayMode!=2){
        g_iRunawayMode=0;
        RunawayMenu(kID,iAuth);
    }
    
    if(iAuth & C_SUPPORT && sCmd == "support")
    {
        // - Initiate Support Mode -
        g_kPendingSupport = kID;
        Dialog(llGetOwner(), "[ZNI Support]\n \nsecondlife:///app/agent/"+(string)kID+"/about is requesting support access. This will grant temporary owner privileges on your collar, you can revoke this at any time by issuing the 'endsupport' command. Do you agree?", [], ["Yes", "No"], 0, C_WEARER, "Consent~Support");
        return;
    }
    
    if(iAuth & (C_OWNER|C_WEARER)){
        integer not_wearer = FALSE;
        if(!iAuth&C_WEARER)not_wearer=TRUE;
        if(sCmd == "safeword-disable" && not_wearer)g_iSafewordDisable=TRUE;
        else if(sCmd == "safeword-enable" && not_wearer)g_iSafewordDisable=FALSE;
            
        list lCmd = llParseString2List(sCmd, [" "],[]);
        string sCmdx = llToLower(llList2String(lCmd,0));
                
        if(sCmdx == "channel" && not_wearer){
            g_iChannel = (integer)llList2String(lCmd,1);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_channel="+(string)g_iChannel, kID);
        }else if(sCmdx == "endsupport")
        {
            if(g_kSupport!=NULL)
            {
                llMessageLinked(LINK_SET, NOTIFY, "1Ending support mode...", kID);
                llMessageLinked(LINK_SET, NOTIFY, "0Support mode is being terminated", g_kSupport);
                g_kSupport=NULL;
                llMessageLinked(LINK_SET, DIALOG_EXPIRE_ALL, "", "");
            }
        } else if(sCmdx == "prefix" && not_wearer){
            if(llList2String(lCmd,1)==""){
                llMessageLinked(LINK_SET,NOTIFY,"0The prefix is currently set to: "+g_sPrefix+". If you wish to change it, supply the new prefix to this same command", kID);
                return;
            }
            g_sPrefix = llList2String(lCmd,1);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_prefix="+g_sPrefix,kID);
        } else if(sCmdx == "add" || sCmdx == "rem"){
            string sType = llToLower(llList2String(lCmd,1));
            string sID;
            if(llGetListLength(lCmd)==3) sID = llList2String(lCmd,2);
                    
            g_kMenuUser=kID;
            g_iCurrentAuth = iAuth;
            if(sCmdx=="add")
                g_iMode = ACTION_ADD;
            else g_iMode=ACTION_REM;
            if(sType == "owner" && not_wearer)g_iMode = g_iMode|ACTION_OWNER;
            else if(sType == "trust")g_iMode = g_iMode|ACTION_TRUST;
            else if(sType == "block")g_iMode=g_iMode|ACTION_BLOCK;
            else return; // Invalid, don't continue
                    
            if(sID == ""){
                // Open Scanner Menu to add
                if(g_iMode&ACTION_ADD){
                    g_iMode = g_iMode|ACTION_SCANNER;
                    llSensor("", "", AGENT, 20, PI);
                } else {
                    list lOpts;
                    if(sType == "owner" && not_wearer)lOpts=g_lOwner;
                    else if(sType == "trust")lOpts=g_lTrust;
                    else if(sType == "block")lOpts=g_lBlock;
                    else return; // deny adding for unknown type
                    
                    
                    Dialog(kID, "zCollar\n\nRemove "+sType, lOpts, [UPMENU],0,iAuth,"removeUser");
                }
            }else {
                UpdateLists((key)sID, kID);
            }
        } 
    }
    if (iAuth &(C_WEARER|C_TRUSTED|C_PUBLIC|C_GROUP|C_BLOCKED)) return;
    if (iAuth &C_COLLAR_INTERNALS && sCmd == "runaway") {
        // trigger runaway sequence if approval was given
        if(g_iRunawayMode == 2){
            g_iRunawayMode=-1;
            llMessageLinked(LINK_SET, NOTIFY_OWNERS, "Runaway completed on %WEARERNAME%'s collar", kID);
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, "auth_owner","origin");
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, "auth_trust","origin");
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, "auth_block","origin");
            llMessageLinked(LINK_SET, NOTIFY, "0Runaway complete", g_kWearer);
            return;
        }
            
    }
    
     if(sCmd == "print auth"){
         if(iAuth &(C_OWNER|C_TRUSTED|C_WEARER))
            PrintAccess(kID);
        else
            llMessageLinked(LINK_SET,NOTIFY, "0%NOACCESS% to printing access lists!", kID);
    }
}
 
SW(){
    llMessageLinked(LINK_SET, NOTIFY,"0You used the safeword, your owners have been notified", g_kWearer);
    llMessageLinked(LINK_SET, NOTIFY_OWNERS, "%WEARERNAME% had to use the safeword. Please check on %WEARERNAME%.","");
}
//integer g_iInterfaceChannel;
//integer g_iLMCounter=0;
integer g_iInterfaceChannel;


integer g_iStartup=TRUE;
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
    on_rez(integer iNum){
        llResetScript();
    }
    
    state_entry(){
        if(llGetStartParameter()!=0)llResetScript();
        g_kWearer = llGetOwner();
        g_sPrefix = llToLower(llGetSubString(llKey2Name(llGetOwner()),0,1));
        // make the API Channel be per user
        while(g_iInterfaceChannel==0){
            g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
            if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        }
        DoListeners();
        
        llSetTimerEvent(15);
        
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL","");
        
            
        
    }
    
    timer(){
        if(llGetInventoryType("zc_states")==INVENTORY_NONE)llSetTimerEvent(0); // The state manager is not installed.
        if(llGetScriptState("zc_states")==FALSE){
            llResetOtherScript("zc_states");
            llSleep(0.5);
            llSetScriptState("zc_states",TRUE);
        }
    }
    
    
    run_time_permissions(integer iPerm) {
        if (iPerm & PERMISSION_ATTACH) {
            llOwnerSay("@detach=yes");
            llDetachFromAvatar();
        }
    }
    
    listen(integer c,string n,key i,string m){
        if(c == g_iInterfaceChannel){
            //do nothing if wearer isnt owner of the object
            if (llGetOwnerKey(i) != g_kWearer) return;
            //play ping pong with the Sub AO
            if (m == "zCollar?") llRegionSayTo(g_kWearer, g_iInterfaceChannel, "zCollar=Yes");
            else if (m == "zCollar=Yes") {
                llOwnerSay("\n\nATTENTION: You are attempting to wear more than one zCollar core. This causes errors with other compatible accessories and your RLV relay. For a smooth experience, and to avoid wearing unnecessary script duplicates, please consider to take off \""+n+"\" manually if it doesn't detach automatically.\n");
                llRegionSayTo(i,g_iInterfaceChannel,"There can be only one!");
            } else if (m == "There can be only one!" ) {
                llOwnerSay("/me has been detached.");
                llRequestPermissions(g_kWearer,PERMISSION_ATTACH);
            }
        }
            
        
        
        if(llToLower(llGetSubString(m,0,llStringLength(g_sPrefix)-1))==llToLower(g_sPrefix)){
            string CMD=llGetSubString(m,llStringLength(g_sPrefix),-1);
            if(llGetSubString(CMD,0,0)==" ")CMD=llDumpList2String(llParseString2List(CMD,[" "],[]), " ");
            llMessageLinked(LINK_SET, CMD_ZERO, CMD, llGetOwnerKey(i));
        } else if(llGetSubString(m,0,0) == "*" && (llGetOwnerKey(i)==i)){ // only for avatars
            string CMD = llGetSubString(m,1,-1);
            if(llGetSubString(CMD,0,0)==" ")CMD=llDumpList2String(llParseString2List(CMD,[" "],[])," ");
            llMessageLinked(LINK_SET, CMD_ZERO, CMD, llGetOwnerKey(i));
        } else {
            list lTmp = llParseString2List(m,[" ","(",")"],[]);
            string sDump = llToLower(llDumpList2String(lTmp, ""));
            
            if(sDump == llToLower(g_sSafeword) && !g_iSafewordDisable && i == g_kWearer){
                llMessageLinked(LINK_SET, CMD_SAFEWORD, "","");
                SW();
            }
        }
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID){
        
        
        
        //if(iNum>=CMD_OWNER && iNum <= CMD_NOACCESS) llOwnerSay(llDumpList2String([iSender, iNum, sStr, kID], " ^ "));
        if(iNum == CMD_ZERO){
            if(sStr == "initialize")return;
            integer iAuth = CalcAuthMask(kID, TRUE);
            //llOwnerSay( "{API} Calculate auth for "+(string)kID+"="+(string)iAuth+";"+sStr);
            llMessageLinked(LINK_SET, COMMAND, (string)iAuth+"|>"+ sStr, kID);
        } else if(iNum == AUTH_REQUEST){
            integer iAuth = CalcAuthMask(kID, FALSE);
            //llOwnerSay("{API} Calculate auth for "+(string)kID+"="+(string)iAuth+";"+sStr);
            llMessageLinked(LINK_SET, AUTH_REPLY, "AuthReply|"+(string)kID+"|"+(string)iAuth,sStr);
        } else if(iNum == COMMAND){
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = (integer)llList2String(lTmp,0);
            UserCommand(iMask, llList2String(lTmp,1), kID);
        }
        else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        }
        else if(iNum == LM_SETTING_RESPONSE){
            list lPar = llParseString2List(sStr, ["_","="],[]);
            string sToken = llList2String(lPar,0);
            string sVar = llList2String(lPar,1);
            string sVal = llList2String(lPar,2);
            
            //integer ind = llListFindList(g_lSettingsReqs, [sToken+"_"+sVar]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            if(sToken == "auth"){
                if(sVar == "owner"){
                    g_lOwner=llParseString2List(sVal, [","],[]);
                } else if(sVar == "trust"){
                    g_lTrust = llParseString2List(sVal,[","],[]);
                } else if(sVar == "block"){
                    g_lBlock = llParseString2List(sVal,[","],[]);
                } else if(sVar == "public"){
                    g_iPublic=(integer)sVal;
                } else if(sVar == "group"){
                    if(sVal == (string)NULL_KEY)sVal="";
                    g_kGroup = (key)sVal;
                    
                    if(g_kGroup!=NULL_KEY)
                        llOwnerSay("@setgroup:"+(string)g_kGroup+"=force,setgroup=n");
                    else llOwnerSay("@setgroup=y");
                } else if(sVar == "limitrange"){
                    g_iLimitRange = (integer)sVal;
                } else if(sVar == "tempowner"){
                    g_kCaptor = (key)sVal;
                } else if(sVar == "runaway"){
                    g_iRunaway=(integer)sVal;
                }
            } else if(sToken == "global"){
                if(sVar == "channel"){
                    g_iChannel = (integer)sVal;
                    DoListeners();
                } else if(sVar == "prefix"){
                    g_sPrefix = sVal;
                } else if(sVar == "safeword"){
                    g_sSafeword = sVal;
                } else if(sVar == "safeworddisable"){
                    g_iSafewordDisable=1;
                }
            } else if(sToken == "intern")
            {
                if(sVar == "supportlockout")
                {
                    g_iSupportLockout = (integer)sVal;
                }
            }
            
            
            if(sStr=="settings=sent"){
                if(g_iStartup){
                    g_iStartup=0;
                    if(llGetListLength(g_lOwner)>0){
                        integer x=0;
                        integer x_end = llGetListLength(g_lOwner);
                        list lMsg = [];
                        for(x=0;x<x_end;x++){
                            key owner = (key)llList2String(g_lOwner,x);
                            if(owner==g_kWearer)lMsg += "Yourself";
                            else lMsg += ["secondlife:///app/agent/"+(string)owner+"/about"];
                        }
                        
                        llMessageLinked(LINK_SET, NOTIFY, "0You are owned by: "+llDumpList2String(lMsg,", "), g_kWearer);
                    }
                }
            }
        } else if(iNum == LM_SETTING_DELETE){
            
            list lPar = llParseString2List(sStr, ["_"],[]);
            string sToken = llList2String(lPar,0);
            string sVar = llList2String(lPar,1);
            
            //integer ind = llListFindList(g_lSettingsReqs, [sStr]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            if(sToken == "auth"){
                if(sVar == "owner"){
                    g_lOwner=[];
                } else if(sVar == "trust"){
                    g_lTrust = [];
                } else if(sVar == "block"){
                    g_lBlock = [];
                } else if(sVar == "public"){
                    g_iPublic=FALSE;
                } else if(sVar == "group"){
                    g_kGroup = NULL_KEY;
                    llOwnerSay("@setgroup=y");
                } else if(sVar == "limitrange"){
                    g_iLimitRange = TRUE;
                } else if(sVar == "tempowner"){
                    g_kCaptor = "";
                } else if(sVar == "runaway"){
                    g_iRunaway=TRUE;
                }
            } else if(sToken == "global"){
                if(sVar == "channel"){
                    g_iChannel = 1;
                    DoListeners();
                } else if(sVar == "prefix"){
                    g_sPrefix = llToLower(llGetSubString(llKey2Name(llGetOwner()),0,1));
                } else if(sVar == "safeword"){
                    g_sSafeword = "RED";
                }
            }
        } else if(iNum == REBOOT){
            llResetScript();
            
        } 
        else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                //integer iRespring=TRUE;
                
                if(sMenu == "scan~add"){
                    if(sMsg == UPMENU){
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu Access", kAv);
                        return;
                    } else if(sMsg == ">Wearer<"){
                        UpdateLists(llGetOwner(), g_kMenuUser);
                        // Not enough time to update the lists via settings. Handle via timer callback.
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)kAv);
                    }else {
                        //UpdateLists((key)sMsg);
                        g_kTry = (key)sMsg;
                        if(!(g_iMode&ACTION_BLOCK))
                            Dialog(g_kTry, "zCollar\n\n"+SLURL(kAv)+" is trying to add you to an access list, do you agree?", ["Yes", "No"], [], 0, (C_ZERO), "scan~confirm");
                        else UpdateLists((key)sMsg, g_kMenuUser);
                    }
                } else if(sMenu == "WearerConfirmation"){
                    if(sMsg == "Allow"){
                        // process
                        g_iGrantedConsent=TRUE;
                        UpdateLists(g_kWearer, g_kMenuUser);
                        // Not enough time to update the lists via settings. Handle via timer callback.
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)g_kMenuUser);
                    } else if(sMsg == "Disallow"){
                        llMessageLinked(LINK_SET, NOTIFY, "0The wearer did not give consent for this action", g_kMenuUser);
                        g_iMode=0;
                        // Not enough time to update the lists via settings. Handle via timer callback.
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)g_kMenuUser);
                    }
                } else if(sMenu == "scan~confirm"){
                    if(sMsg == "No"){
                        g_iMode = 0;
                        llMessageLinked(LINK_SET, 0, "menu Access", kAv);
                        llMessageLinked(LINK_SET, NOTIFY,  "1" + SLURL(kAv) + " declined being added to the access list.", g_kWearer);
                    } else if(sMsg == "Yes"){
                        UpdateLists(g_kTry, g_kMenuUser);
                        // Not enough time to update the lists via settings. Handle via timer callback.
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)kAv);
                    }
                } else if(sMenu == "removeUser"){
                    if(sMsg == UPMENU){
                        // Not enough time to update the lists via settings. Handle via timer callback.
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "2", "spring_access:"+(string)kAv);
                    }else{
                        UpdateLists(sMsg, g_kMenuUser);
                    }
                } else if(sMenu == "RunawayMenu"){
                    if(sMsg == "Enable" && iAuth & C_OWNER){
                        g_iRunaway=TRUE;
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE, "AUTH_runaway","origin");
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)kAv);
                    } else if(sMsg == "Disable"){
                        g_iRunaway=FALSE;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "AUTH_runaway=0", "origin");
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)kAv);
                    } else if(sMsg == "No"){
                        // return
                        g_iRunawayMode=-1;
                        llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "2", "spring_access:"+(string)kAv);
                        return;
                    } else if(sMsg == "Yes"){
                        // trigger runaway
                        if(iAuth &(C_WEARER|C_OWNER) && g_iRunaway){
                            g_iRunawayMode=2;
                            llMessageLinked(LINK_SET, NOTIFY_OWNERS, "%WEARERNAME% has runaway.", "");
                            llMessageLinked(LINK_SET, COMMAND, (string)C_COLLAR_INTERNALS+"|>runaway", g_kWearer);
                            llMessageLinked(LINK_SET, CMD_SAFEWORD, "safeword", "");
                            llMessageLinked(LINK_SET, COMMAND, "1|>clear", g_kWearer);
                            
                            llMessageLinked(LINK_SET, TIMEOUT_REGISTER, "5", "spring_access:"+(string)kAv);
                        }
                    }
                } else if(sMenu == "Consent~Support")
                {
                    if(sMsg == "No")
                    {
                        llMessageLinked(LINK_SET, NOTIFY, "0%NOACCESS% to activating support", g_kPendingSupport);
                        g_kPendingSupport=NULL;
                    }else if(sMsg == "Yes")
                    {
                        llMessageLinked(LINK_SET, NOTIFY, "1Support mode is activating... Stand by", g_kPendingSupport);
                        g_kSupport=g_kPendingSupport;
                        g_kPendingSupport=NULL;
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu /support", g_kSupport);
                        llWhisper(0, "ZNI Support Mode activated by secondlife:///app/agent/"+(string)g_kSupport+"/about\n \n[To end: "+g_sPrefix+" endsupport]");
                    }
                }
            }
        } else if(iNum == RLV_REFRESH){
            if(g_kGroup==NULL_KEY)llOwnerSay("@setgroup=y");
            else llOwnerSay("@setgroup:"+(string)g_kGroup+"=force;setgroup=n");
        } else if(iNum == UPDATER){
            if(sStr == "update_active")llResetScript();
        } else if(iNum == TIMEOUT_FIRED)
        {
            list lTmp = llParseString2List(sStr, [":"],[]);
            if(llList2String(lTmp,0)=="spring_access"){
                llMessageLinked(LINK_SET,0,"menu Access", (key)llList2String(lTmp,1));
            }
        }
    }
    sensor(integer iNum){
        if(!(g_iMode&ACTION_SCANNER))return;
        list lPeople = [];
        integer i=0;
        for(i=0;i<iNum;i++){
            if(llGetListLength(lPeople)<10){
                //llSay(0, "scan: "+(string)i+";"+(string)llGetListLength(lPeople)+";"+(string)g_iMode);
                if(llDetectedKey(i)!=llGetOwner())
                    lPeople += llDetectedKey(i); 
                
            } else {
                //llSay(0, "scan: invalid list length: "+(string)llGetListLength(lPeople)+";"+(string)g_iMode);
            }
        }
        
        Dialog(g_kMenuUser, "zCollar\nAdd Menu", lPeople, [">Wearer<",UPMENU], 0, g_iCurrentAuth, "scan~add");
    }
    
    no_sensor(){
        if(!(g_iMode&ACTION_SCANNER))return;
        
        Dialog(g_kMenuUser, "zCollar\nAdd Menu", [], [">Wearer<", UPMENU], 0, g_iCurrentAuth, "scan~add");
    }
}
