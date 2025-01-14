  
/*
This file is a part of zCollar.
Copyright ©2020


: Contributors :

Aria (Tashia Redrose)
    * April 2021        -       Rebranded under zCollar
                                Add Support Menu and command to states script
    *August 2020       -       Created oc_states
                    -           Due to significant issues with original implementation, States has been turned into a anti-crash script instead of a script state manager.
                    -           Repurpose oc_states to be anti-crash and a interactive settings editor.
    
    
et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/ZNICreations/zCollar

*/
#include "MasterFile.lsl"

integer g_iVerbosityLevel = 1;




SettingsMenu(integer stridePos, key kAv, integer iAuth)
{
    string sText = "zCollar - Interactive Settings editor";
    list lBtns = [];
    if(!(iAuth & C_OWNER)){
        sText+="\n\nOnly owner may use this feature";
        Dialog(kAv, sText, [], [UPMENU], 0, iAuth, "Menu~Main");
        return;
    }
    if(stridePos == 0){
        integer i=0;
        integer end = llGetListLength(g_lSettings);
        for(i=0;i<end;i+=3){
            if(llListFindList(lBtns,[llList2String(g_lSettings,i)])==-1)lBtns+=llList2String(g_lSettings,i);
        }            
        sText+="\nCurrently viewing Tokens";
    } else if(stridePos==1){
        integer i=0;
        integer end = llGetListLength(g_lSettings);
        for(i=0;i<end;i+=3){
            if(llList2String(g_lSettings,i)==g_sTokenView){
                lBtns+=llList2String(g_lSettings,i+1);
            }
        }
        sText+="\nCurrently viewing Variables for token '"+g_sTokenView+"'";
    } else if(stridePos == 2){
        integer iPos = llListFindList(g_lSettings,[g_sTokenView,g_sVariableView]);
        if(iPos==-1){
            // cannot do it
            lBtns=[];
            sText+="\nCurrently viewing the variable '"+g_sTokenView+"_"+g_sVariableView+"'\nNo data found";
        } else {
            lBtns = ["DELETE", "MODIFY"];
            sText = "\nCurrently viewing the variable '"+g_sTokenView+"_"+g_sVariableView+"'\nData contained in var: "+llList2String(g_lSettings, iPos+2);
        }
    } else if(stridePos==3){
        integer iPos = llListFindList(g_lSettings,[g_sTokenView,g_sVariableView]);
        sText+="\n\nPlease enter a new value for: "+g_sTokenView+"_"+g_sVariableView+"\n\nCurrent value: "+llList2String(g_lSettings, iPos+2);
        lBtns =[];
    } else if(stridePos==8){
        sText+= "\n\nPlease enter the token name";
        lBtns=[];
    } else if(stridePos == 9){
        sText += "\n\nPlease enter the variable name for '"+g_sTokenView;
        lBtns=[];
    }
    
    g_iLastStride=stridePos;
    Dialog(kAv, sText,lBtns, setor((lBtns!=[]), ["+ NEW", UPMENU], []), 0, iAuth, "settings~edit~"+(string)stridePos);
    
}
SupportSettings(key kID, integer iAuth)
{
    Dialog(kID, "[zCollar Support Settings]\n \n* ZNI SUPPORT SETTINGS *\n\n> LockOut - Locks out support for wearer. This also changes the updater protocol, locking out the wearer from using an updater", [Checkbox(g_iSupportLockout, "LockOut"), "INITIATE"], [UPMENU], 0, iAuth, "support~S");
}

SupportMenu(key kID, integer iAuth)
{
    Dialog(kID, "[ZNI Support]\n \n* CAUTION IS ADVISED *\n\n> Reformat \t\t- Erases all settings\n> END \t\t- End Support", ["Reformat", "END", "Unleash", "Unweld"], [UPMENU], 0, iAuth, "support");
}

list setor(integer test, list a, list b){
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
list g_lSettings;
integer g_iLoading;
//key g_kWearer;
//list g_lOwner;
//list g_lTrust;
key g_kMenuUser;
integer g_iLastAuth;
//list g_lBlock;
string g_sVariableView;
//integer g_iLocked=FALSE;
string g_sTokenView="";
integer g_iLastStride;
integer g_iWaitMenu;

list g_lTimers; // signal, start_time, seconds_from

integer g_iExpectAlive=0;
list g_lAlive;
integer g_iPasses=-1;

//////#define DEBUG_STARTUP

#ifdef DEBUG_STARTUP
integer START_TIME = 0;
integer END_TIME = 0;
PrintStartupTime(){
    llWhisper(0, "Collar took "+(string)(END_TIME-START_TIME)+" seconds to finish SPP");
}
#endif

integer g_iLastRepCheck = 0;
integer g_iStarted;

default
{
    state_entry()
    {
        if(llGetStartParameter() != 0) state inUpdate;
        
        #ifdef DEBUG_STARTUP
        START_TIME=llGetUnixTime();
        #endif
        
        //g_iLastRepCheck = llGetUnixTime();
        g_lAlive=[];
        g_iPasses=0;
        g_iExpectAlive=1;
        llSetTimerEvent(1);
        //llScriptProfiler(TRUE);
        llMessageLinked(LINK_SET, REBOOT,"reboot", "");
        
        //llMessageLinked(LINK_SET, 0, "initialize", "");
        if(g_iVerbosityLevel>=1)
            llOwnerSay("Collar is preparing to startup, please be patient.");
    }
    
    
    on_rez(integer iRez){
        llResetScript();
    }
    
    timer(){
        if(g_iExpectAlive){
            if(llGetTime()>=5 && g_iPasses<2){
                llMessageLinked(LINK_SET,READY, "","");
                llResetTime();
                //llSay(0, "PASS COUNT: "+(string)g_iPasses);
                g_iPasses++;
            } else if(llGetTime()>=4.5 && g_iPasses>=2){
                if(g_iVerbosityLevel>=2)
                    llOwnerSay("Scripts ready: "+(string)llGetListLength(g_lAlive));
                llMessageLinked(LINK_SET,STARTUP,llDumpList2String(g_lAlive,","),"");
                g_iExpectAlive=0;
                g_iStarted=TRUE;
                g_lAlive=[];
                g_iPasses=0;
                llSleep(10);
                
                if(g_iVerbosityLevel >=1)
                    llMessageLinked(LINK_SET,NOTIFY,"0Startup in progress... be patient", llGetOwner());
                //llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"ALL","");
                llMessageLinked(LINK_SET,0,"initialize","");
                
                #ifdef DEBUG_STARTUP
                END_TIME=llGetUnixTime();
                PrintStartupTime();
                #endif
            }
            
            return;
        }
        
        if(llGetUnixTime() >= g_iLastRepCheck+(30*60) && g_iStarted){
            UpdateDSRequest(NULL, llHTTPRequest("https://api.zontreck.dev/zni/Get_Support.php",[],""), SetMetaList(["check_support"]));
            g_iLastRepCheck=llGetUnixTime();
        }

        if(!g_iWaitMenu && llGetListLength(g_lTimers) == 0)
            llSetTimerEvent(15);
        // Check all script states, then check list of managed scripts
        integer i=0;
        integer end = llGetInventoryNumber(INVENTORY_SCRIPT);
        integer iModified=FALSE;
        for(i=0;i<end;i++){
            string scriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
            // regular anti-crash
            if(llGetScriptState(scriptName)==FALSE){
                llResetOtherScript(scriptName);
                llSleep(0.5);
                llSetScriptState(scriptName,TRUE);
                llSleep(1);
                iModified=TRUE;
                
                if(g_iVerbosityLevel >=1)
                    llMessageLinked(LINK_SET, NOTIFY, "0"+scriptName+" has been reset. If the script stack heaped, please file a bug report on our github.", llGetOwner());
            }
        }
        
        if(iModified) llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL","");
        
        if(!g_iLoading && g_iWaitMenu){
            g_iWaitMenu=FALSE;
            SettingsMenu(0,g_kMenuUser,g_iLastAuth);
        }
        
        
        // proceed
        i=0;
        end = llGetListLength(g_lTimers);
        for(i=0;i<end;i+=3){
            integer now = llGetUnixTime();
            integer start = llList2Integer(g_lTimers, i+1);
            integer diff = llList2Integer(g_lTimers,i+2);
            if((now-start)>=diff){
                string signal = llList2String(g_lTimers,i);
                
                g_lTimers = llDeleteSubList(g_lTimers, i,i+2);
                i=0;
                end=llGetListLength(g_lTimers);
                llMessageLinked(LINK_SET, TIMEOUT_FIRED, signal, "");
                
            }
        }
        
        //llWhisper(0, "oc_states max used over time: "+(string)llGetSPMaxMemory());
    }

    http_response(key kID, integer iStat, list lM, string sBody){
        if(HasDSRequest(kID)!=-1){
            list lMeta = GetMetaList(kID);
            if(llList2String(lMeta,0)=="check_support"){
                list lTmp = llParseString2List(sBody, [";;",";", "~"],[]);
                lTmp = llDeleteSubList(lTmp,0,0);
                if(lTmp != g_lSupportReps){
                    g_lSupportReps = lTmp;
                    llMessageLinked(LINK_SET, UPDATE_SUPPORT_REPS, llDumpList2String(g_lSupportReps,","), "");
                    if(g_iVerbosityLevel>=2){
                        llWhisper(0, "[ ZNI Server ]\n \n* New Support Reps have been downloaded\n* You are only seeing this because debug is enabled");
                        integer ix=0;
                        integer ixend = llGetListLength(g_lSupportReps);
                        for(ix=0;ix<ixend;ix++){
                            llWhisper(0, "[ZNI Support] "+SLURL(llList2String(g_lSupportReps,ix)));
                        }
                    }
                }
            }
            DeleteDSReq(kID);
        }
    }
    
    
    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum == REBOOT && sStr == "reboot --f")llResetScript();
        
        if(iNum == COMMAND){
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = llList2Integer(lTmp,0);
            string sCmd = llList2String(lTmp,1);
            if(!(iMask&(C_OWNER))){
                if(iMask&C_SUPPORT)
                {
                    if(llToLower(sCmd) == "menu /support")
                    {
                        llMessageLinked(LINK_SET, 0, "support", kID);
                        return;
                    }
                }
                return;
            }
            if(sCmd == "fix"){
                g_iExpectAlive=1;
                llResetTime();
                g_iPasses=0;
                g_lAlive=[];
                g_iLoading=FALSE;
                g_lSettings=[];
                
                llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
            }
            if(llToLower(sCmd)=="settings edit"){
                g_lSettings=[];
                g_iLoading=TRUE;
                g_iWaitMenu=TRUE;
                g_kMenuUser=kID;
                g_iLastAuth=iNum;
                llResetTime();
                llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL","");
                llSetTimerEvent(1);
            }
            if(llToLower(sCmd) == "menu /support" && (iMask&C_SUPPORT))
            {
                SupportMenu(kID, iMask);
            }
            if(llToLower(sCmd) == "menu support_settings" && (iMask&(C_OWNER|C_SUPPORT)))
            {
                SupportSettings(kID, iMask);
            }
        } else if(iNum == TIMEOUT_REGISTER){
            g_lTimers += [(string)kID, llGetUnixTime(), (integer)sStr];
            llResetTime();
            llSetTimerEvent(1);
        } else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                integer iRemenu=TRUE;
                
                if(sMenu == "Menu~Main"){
                    if(sMsg == UPMENU){
                        iRemenu=FALSE;
                        llMessageLinked(LINK_SET, COMMAND, (string)iAuth+ "|>menu Settings", kAv);
                    }
                } else if(sMenu == "settings~edit~0"){
                    if(sMsg == UPMENU){
                        llMessageLinked(LINK_SET, COMMAND, (string)iAuth +"|>menu Settings", kAv);
                        return;
                    } else if(sMsg == "+ NEW"){
                        SettingsMenu(8, kAv, iAuth);
                        return;
                    }
                    if(sMsg == "intern" || sMsg == "auth"){
                        llMessageLinked(LINK_SET, NOTIFY, "0Editing of the "+sMsg+" token is prohibited by the security policy", kAv);
                        SettingsMenu(0, kAv, iAuth);
                    } else {
                        g_sTokenView=sMsg;
                        SettingsMenu(1, kAv,iAuth);
                    }
                } else if(sMenu == "settings~edit~1"){
                    if(sMsg==UPMENU){
                        SettingsMenu(0,kAv,iAuth);
                        return;
                    }else if(sMsg == "+ NEW"){
                        SettingsMenu(9, kAv, iAuth);
                        return;
                    }
                    
                    g_sVariableView=sMsg;
                    SettingsMenu(2, kAv,iAuth);
                    
                } else if(sMenu == "settings~edit~2"){
                    if(sMsg == UPMENU){
                        SettingsMenu(1,kAv,iAuth);
                        return;
                    } else if(sMsg == "DELETE"){
                        integer iPosx = llListFindList(g_lSettings,[g_sTokenView,g_sVariableView]);
                        if(iPosx==-1){
                            SettingsMenu(2,kAv,iAuth);
                            return;
                        }
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sTokenView+"_"+g_sVariableView,"");
                        llMessageLinked(LINK_SET, RLV_REFRESH,"","");
                        llMessageLinked(LINK_SET, NOTIFY, "1"+g_sTokenView+"_"+g_sVariableView+" has been deleted from settings", kAv);
                        g_iLoading=TRUE;
                        g_lSettings=[];
                        g_iWaitMenu=TRUE;
                        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL","");
                        llSetTimerEvent(1);
                        return;
                    } else if(sMsg == "MODIFY"){
                        SettingsMenu(3, kAv,iAuth);
                    }
                } else if(sMenu == "settings~edit~3"){
                    if(sMsg == UPMENU){
                        SettingsMenu(2,kAv,iAuth);
                    } else {
                        integer iPosx = llListFindList(g_lSettings, [g_sTokenView, g_sVariableView]);
                        if(iPosx == -1)SettingsMenu(2,kAv,iAuth);
                        else{
                            g_lSettings = llListReplaceList(g_lSettings, [sMsg], iPosx+2,iPosx+2);
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sTokenView+"_"+g_sVariableView+"="+sMsg,"");
                            llMessageLinked(LINK_SET, NOTIFY, "1Settings modified: "+g_sTokenView+"_"+g_sVariableView+"="+sMsg,kAv);
                            SettingsMenu(1,kAv,iAuth);
                            return;
                        }
                    }
                } else if(sMenu == "settings~edit~8"){
                    g_sTokenView=sMsg;
                    SettingsMenu(9, kAv,iAuth);
                } else if(sMenu == "settings~edit~9"){
                    g_sVariableView=sMsg;
                    g_lSettings += [g_sTokenView,g_sVariableView,"not set"];
                    
                    SettingsMenu(3, kAv,iAuth);
                } else if(sMenu == "support")
                {
                    if(sMsg == UPMENU)
                    {
                        llMessageLinked(LINK_SET, 0, "menu", kAv);
                        iRemenu = FALSE;
                    } else if(sMsg == "Reformat")
                    {
                        llMessageLinked(LINK_SET, LM_SETTING_RESET, "", kAv);
                    } else if(sMsg == "END")
                    {
                        llMessageLinked(LINK_SET, 0, "endsupport", kAv);
                    } else if(sMsg == "Unleash")
                    {
                        llMessageLinked(LINK_SET, COMMAND, (string)C_COLLAR_INTERNALS+"|>unleash", kAv);
                    } else if(sMsg == "Unweld")
                    {
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE, "intern_weld", kAv);
                    }
                    
                    if(iRemenu)SupportMenu(kAv,iAuth);
                } else if(sMenu == "support~S")
                {
                    if(sMsg == UPMENU)
                    {
                        llMessageLinked(LINK_SET,0,"menu",kAv);
                        iRemenu = FALSE;
                    } else if(sMsg == "INITIATE")
                    {
                        llMessageLinked(LINK_SET,0,"support",kAv);
                        iRemenu=FALSE;
                    } else if(sMsg == Checkbox(g_iSupportLockout,"LockOut"))
                    {
                        if(iAuth & (C_OWNER|C_SUPPORT)){
                            g_iSupportLockout=1-g_iSupportLockout;
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "intern_supportlockout="+(string)g_iSupportLockout, "origin");
                        }
                    }
                    
                    if(iRemenu)SupportSettings(kAv,iAuth);
                }
                        
            }
            
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        }else if(iNum == LM_SETTING_RESPONSE){
            // Detect here the Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);
            string sToken = llList2String(lSettings,0);
            string sVar = llList2String(lSettings,1);
            string sVal = llList2String(lSettings, 2);
            if(sToken == "global"){
                if(sVar == "verbosity"){
                    g_iVerbosityLevel = (integer)sVal;
                }
            }else if(sToken == "intern")
            {
                if(sVar == "supportlockout")
                {
                    g_iSupportLockout=(integer)sVal;
                }
            }
            
            
            if(sStr == "settings=sent"){
                g_iLoading=FALSE;
                return;
            }
            
            if(g_iLoading && llListFindList(g_lSettings, [sToken, sVar, sVal]) == -1 )g_lSettings+=[sToken, sVar, sVal];
            
        } else if(iNum == 0){
            if(sStr == "initialize"){
                llMessageLinked(LINK_SET, TIMEOUT_READY, "","");
            }
        }else if(iNum == UPDATER){
            if(sStr == "update_active")state inUpdate;
        } else if(iNum == ALIVE){
            g_iExpectAlive=1;
            
            
            if(llListFindList(g_lAlive,[sStr])==-1){
                g_iPasses=0;
                #ifdef DEBUG_STARTUP
                llWhisper(0, "Script ("+sStr+") seen "+(string)llGetTime()+" seconds after last script");
                #endif
                g_lAlive+=[sStr];
            }else return;
            llResetTime();
            llSetTimerEvent(1);
        }
    }
}

state inUpdate
{
    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum == REBOOT)llResetScript();
    }
    on_rez(integer iNum){
        llResetScript();
    }
}
