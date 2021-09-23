/*

Copyright ZNI 2021


Animation Helper Script
> Purpose: For priority 5 animations that only modify a few joints

*/
#include "MasterFile.lsl"

string g_sParentMenu = "Apps";
string g_sSubMenu = "AnimHelper";


Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

integer BEHIND_BACK=1;
integer HANDS_FRONT=2;

integer g_iCurrentMask;

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Animation Helper]";
    list lButtons = [Checkbox((g_iCurrentMask&BEHIND_BACK), "Behind Back"), Checkbox((g_iCurrentMask&HANDS_FRONT), "Hands Front")];
    Dialog(kID, sPrompt, lButtons, [UPMENU, "OFF"], 0, iAuth, "Menu~Main");
}

UserCommand(integer iNum, string sStr, key kID) {
    if(!(iNum&(C_OWNER|C_TRUSTED|C_WEARER)))return; // This example plugin limits menu and command access to owner, trusted, and wearer
    if (llSubStringIndex(llToLower(sStr),llToLower(g_sSubMenu)) && llToLower(sStr) != "menu "+llToLower(g_sSubMenu)) return;
    if (iNum & C_OWNER && llToLower(sStr) == "runaway") {
        g_lOwner=[];
        g_lTrust=[];
        g_lBlock=[];
        return;
    }
    if (llToLower(sStr)==llToLower(g_sSubMenu) || llToLower(sStr) == "menu "+llToLower(g_sSubMenu)) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        //integer iWSuccess = 0; 
        string sChangetype = llList2String(llParseString2List(sStr, [" "], []),1);
        string sChangevalue = llList2String(llParseString2List(sStr, [" "], []),2);
        //string sText;
        /// [prefix] g_sSubMenu sChangetype sChangevalue
        if(sChangetype == "behindback"){
            g_iCurrentMask = BEHIND_BACK;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "animhelper_mask="+(string)g_iCurrentMask, "origin");
        }else if(sChangetype == "handsfront"){
            g_iCurrentMask = HANDS_FRONT;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "animhelper_mask="+(string)g_iCurrentMask, "origin");
        } else if(sChangetype == "off"){
            g_iCurrentMask = 0;
            llMessageLinked(LINK_SET, LM_SETTING_DELETE ,"animhelper_behindback", "origin");
            llMessageLinked(LINK_SET, LM_SETTING_DELETE ,"animhelper_mask", "origin");
            ApplyPose();
        }
    }
}

key g_kWearer;
list g_lOwner;
list g_lTrust;
list g_lBlock;
integer g_iLocked=FALSE;

string g_sCurrent="";

ApplyPose(){
    if(g_sCurrent!=""){
        llStopAnimation(g_sCurrent);
        g_sCurrent="";
    }
    if(g_iCurrentMask&BEHIND_BACK){
        g_sCurrent = "_behind_back";
    }
    if(g_iCurrentMask&HANDS_FRONT){
        g_sCurrent = "_hands_front";
    }
    
    
    if(g_sCurrent=="")return;
    llStartAnimation(g_sCurrent);
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
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
    }
    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum == COMMAND) {
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
                
                integer iRespring=TRUE;
                if(sMenu == "Menu~Main"){
                    if(sMsg == UPMENU) {
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                    }
                    else if(sMsg == Checkbox((g_iCurrentMask&BEHIND_BACK), "Behind Back")){
                        g_iCurrentMask=BEHIND_BACK;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "animhelper_mask="+(string)g_iCurrentMask, "origin");
                    } else if(sMsg == Checkbox((g_iCurrentMask&HANDS_FRONT), "Hands Front")){
                        g_iCurrentMask = HANDS_FRONT;
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "animhelper_mask="+(string)g_iCurrentMask, "origin");
                    } else if(sMsg == "OFF"){
                        g_iCurrentMask = 0;
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE, "animhelper_mask", "origin");
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE ,"animhelper_behindback", "origin");
                        ApplyPose();
                    }
                    
                    if(iRespring)Menu(kAv,iAuth);
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
            
            if(sToken == "animhelper"){
                if(sVar == "mas"){
                    g_iCurrentMask = (integer)sVal;
                    ApplyPose();
                }
            }
            
            if(sStr == "settings=sent"){
                ApplyPose();
            }
        }
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}
