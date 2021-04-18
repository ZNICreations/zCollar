/*
This file is a part of zCollar.
Copyright 2021

: Contributors :
Aria (Tashia Redrose)
    * April 2021    -   Rebranded under zCollar: zc_titler
    * Mar 2020      - Fix bug where title would not detect the float text prim.
                    - Fixed bug where titler would display garbled text as a result of failing to decode base64
    * Jan 2020      - Rewrote titler to cleanup the code and make easier to read

et al.

Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/
#include "MasterFile.lsl"

string g_sParentMenu = "Apps";
string g_sSubMenu = "Titler";
string g_sVersion = "8.0"; // leave unmodified if not changed at all after release, otherwise change to next version number

DebugOutput(key kID, list ITEMS){
    integer i=0;
    integer end=llGetListLength(ITEMS);
    string final;
    for(i=0;i<end;i++){
        final+=llList2String(ITEMS,i)+" ";
    }
    llInstantMessage(kID, llGetScriptName() +" "+final);
}
integer g_iNoB64=FALSE; // Use base64 by default
integer g_iWasUpgraded=FALSE; // This will not harm anything if set to true after being upgraded. However, it should eventually be set to false again


integer bool(integer a){
    if(a)return TRUE;
    else return FALSE;
}
list g_lCheckboxes=["⬜","⬛"];
string Checkbox(integer iValue, string sLabel) {
    return llList2String(g_lCheckboxes, bool(iValue))+" "+sLabel;
}
Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Titler]";
    list lButtons = ["UP","DOWN", "Set Title", "Color", Checkbox(g_iShow, "Show")];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Titler");
}

ColorMenu(key kAv, integer iAuth){
    string sPrompt = "\n[Titler]\nColor selection";
    //list lButtons = ["White", "Green", "Yellow", "Cyan", "Blue", "Pink", "Orange"];
    Dialog(kAv, sPrompt, ["colormenu please"], [UPMENU, "Custom"], 0, iAuth, "Menu~Colors");
}


UserCommand(integer iNum, string sStr, key kID) {
    if(!(iNum&(C_OWNER|C_WEARER)))return;
    //if (llSubStringIndex(llToLower(sStr),llToLower(g_sSubMenu)) && llToLower(sStr) != "menu "+llToLower(g_sSubMenu)) return;
    if (iNum & C_OWNER && sStr == "runaway") {
        g_lOwner = g_lTrust = g_lBlock = [];
        return;
    }
    if (llToLower(sStr)==llToLower(g_sSubMenu) || llToLower(sStr) == "menu "+llToLower(g_sSubMenu)) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        //integer iWSuccess = 0; 
        string sChangetype = llList2String(llParseString2List(sStr, [" "], []),0);
        string sChangevalue = llToLower(llList2String(llParseString2List(sStr, [" "], []),1));
        string sParam = llList2String(llParseString2List(sStr, [" "], []),2);
        //string sText;
        if(!(iNum &C_OWNER))return;
        
        if(sChangetype == "title"){
            g_sTitle = llDumpList2String(llList2List(llParseString2List(sStr,[" "],[]), 1,-1)," ");
            if(g_sTitle == ""){
                Dialog(kID, "What should the title say?", [], [], 0, iNum, "Textbox~Title");
                
            }
            Save();
        } else if(sChangetype == "titler"){
            if(sChangevalue == "color"){
                g_vColor=(vector)sParam;
                Save();
            } else if(sChangevalue == "show"){
                g_iShow=TRUE;
                Save();
            } else if(sChangevalue == "hide"){
                g_iShow=FALSE;
                Save();
            } else if(sChangevalue == "up"){
                g_iOffset++;
                Save();
            } else if(sChangevalue == "down"){
                g_iOffset--;
                if(g_iOffset<0)g_iOffset=0;
                Save();
            }else if(sChangevalue == "plain"){
                g_iNoB64 = ! g_iNoB64;
                Save();
                        
                string ToggleMsg = "0Titler plain text mode is now set to ";
                
                if(g_iNoB64) {
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_plain=1", "");
                    ToggleMsg += "PLAIN";
                } else {
                    ToggleMsg += "BASE64";
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "titler_plain", "");
                }
                llMessageLinked(LINK_SET, NOTIFY, ToggleMsg, kID);
            } else if(sChangevalue == "title"){
                g_sTitle = llDumpList2String(llList2List(llParseString2List(sStr,[" "],[]), 2,-1)," ");
                UserCommand(iNum, "title "+g_sTitle, kID);
            }
        }
    }
}
integer g_iShow=FALSE;
Save(){
    if(g_iShow)llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_show=1","");
    else llMessageLinked(LINK_SET, LM_SETTING_DELETE, "titler_show","");
    
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_offset="+(string)g_iOffset, "");
    
    if(!g_iNoB64)
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_title="+llStringToBase64(g_sTitle), "");
    else
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_title="+g_sTitle, "");
    
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_color="+(string)g_vColor,"");
    
    
    Titler();
}

Titler(){
    llSetTimerEvent(2.5);
    // Show the title if applicable after 5 seconds
    
}
key g_kWearer;
integer g_iOffset=8;
vector g_vColor = <1,1,1>;
string g_sTitle;
list g_lOwner;
list g_lTrust;
list g_lBlock;
integer g_iLocked=FALSE;
integer g_iTextPrim;

ScanFloatText(){
    integer i=LINK_ROOT;
    integer end = llGetNumberOfPrims();
    
    for(i=0;i<=end;i++){
        list Params = llGetLinkPrimitiveParams(i, [PRIM_NAME,PRIM_DESC]);
        if(llSubStringIndex(llList2String(Params,0), "FloatText")!=-1){
            g_iTextPrim = i;
            return;
        }
        
        if(llSubStringIndex(llList2String(Params,1), "FloatText")!=-1){
            g_iTextPrim=i;
            return;
        }
    }
    g_iTextPrim=LINK_THIS;
}

NukeOtherText(){
    integer i = 1;
    integer end = llGetNumberOfPrims();
    for(i=1;i<=end;i++){
        llSetLinkPrimitiveParamsFast(i,[PRIM_TEXT, "", ZERO_VECTOR,0]);
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
        llResetScript();
    }
    state_entry()
    {
        if(llGetStartParameter()!=0)llResetScript();
        llSetMemoryLimit(40000);
        g_kWearer = llGetOwner();
        
        NukeOtherText();
        //llOwnerSay((string)llGetUsedMemory());
    }
    timer(){
        // calculate offset
        if(g_iShow){
            string offsets = "";
            integer i=0;
            for(i=0;i<g_iOffset;i++){
                offsets+=" \n";
            }
            llSetLinkPrimitiveParams(g_iTextPrim, [PRIM_TEXT, g_sTitle+offsets, g_vColor, 1]);
        }else llSetLinkPrimitiveParams(g_iTextPrim, [PRIM_TEXT, "", ZERO_VECTOR, 0]);
        llSetTimerEvent(0);
    }
    
    changed(integer iChange){
        if(iChange&CHANGED_LINK){
            integer iCur = g_iTextPrim;
            ScanFloatText();
            if(g_iTextPrim!=iCur)NukeOtherText();
            Titler();
            
        }
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
                
                // There's really nothing that non-owner could change down here, so..
                if(!(iAuth & C_OWNER)){
                    llMessageLinked(LINK_SET, NOTIFY, "0%NOACCESS% to titler options", kAv);
                    llMessageLinked(LINK_SET, COMMAND, (string)iAuth+ "|>menu "+g_sParentMenu, kAv);
                    return;
                }
                if(sMenu == "Menu~Titler"){
                    
                    if(sMsg == UPMENU){
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                    }
                    else if(sMsg == "UP"){
                        g_iOffset++;
                        
                        Save();
                    } else if(sMsg == "DOWN"){
                        g_iOffset--;
                        if(g_iOffset<0)g_iOffset=0;
                        Save();
                    } else if(sMsg == Checkbox(g_iShow,"Show")){
                        g_iShow=!g_iShow;
                        Save();
                        
                    } else if(sMsg == "Set Title"){
                        iRespring=FALSE;
                        Dialog(kAv, "What should the title say?", [], [], 0, iAuth, "Textbox~Title");
                        
                    } else if(sMsg == "Color")
                    {
                        // Open default colors menu
                        ColorMenu(kAv,iAuth);
                        iRespring=FALSE;
                    }
                    
                    if(iRespring)Menu(kAv,iAuth);
                } else if(sMenu == "Menu~Colors"){
                    if(sMsg == UPMENU){
                        Menu(kAv, iAuth);
                        iRespring=FALSE;
                    } else if(sMsg == "Custom"){
                        Dialog(kAv, "[Titler Custom Color]", [], [], 0, iAuth, "Textbox~Color");
                        iRespring=FALSE;
                    } else  {
                        g_vColor = (vector)sMsg;
                    }
                    
                    if(iRespring)ColorMenu(kAv,iAuth);
                    
                    Save();
                } else if(sMenu == "Textbox~Title"){
                    g_sTitle = sMsg;
                    
                    // pop menu back up
                    Menu(kAv, iAuth);
                    Save();
                } else if(sMenu == "Textbox~Color"){
                    g_vColor = (vector)sMsg;
                    
                    ColorMenu(kAv,iAuth);
                    Save();
                }
            }
        }else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == LM_SETTING_RESPONSE){
            // Detect here the Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);
            
            
            //integer ind = llListFindList(g_lSettingsReqs, [llList2String(lSettings,0)+"_"+llList2String(lSettings,1)]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            
            if(llList2String(lSettings,0)=="global"){
                if(llList2String(lSettings,1)=="locked"){
                    g_iLocked=llList2Integer(lSettings,2);
                } else if(llList2String(lSettings,1) == "checkboxes"){
                    g_lCheckboxes = llCSV2List(llList2String(lSettings,2));
                }
            } else if(llList2String(lSettings,0) == "titler"){
                integer curPrim=g_iTextPrim;
                ScanFloatText();
                
                if(g_iTextPrim!=curPrim)NukeOtherText(); // permit changing the float text prim
                
                if(llList2String(lSettings,1) == "show"){
                    g_iShow=TRUE;
                }else if(llList2String(lSettings,1) == "offset"){
                    g_iOffset=(integer)llList2String(lSettings,2);
                }else if(llList2String(lSettings,1) == "title"){
                    if(!g_iNoB64)
                        g_sTitle = llBase64ToString(llList2String(lSettings,2)); // We can't really check if this is a base64 string
                    else
                        g_sTitle = llList2String(lSettings,2);
                        
                    if(g_iWasUpgraded) {
                        g_sTitle = llList2String(lSettings,2);
                        if(!g_iNoB64)
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_title="+llStringToBase64(g_sTitle), "");
                        else
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_title="+g_sTitle, "");
                        g_iWasUpgraded=FALSE;
                    }
                } else if(llList2String(lSettings,1)=="color"){
                    g_vColor=(vector)llList2String(lSettings,2);
                } else if(llList2String(lSettings,1) == "on"){
                    // this was definitely a upgrade. Re-request!
                    g_iWasUpgraded=TRUE;
                    llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
                    
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "titler_auth", "");
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "titler_on", "");
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "titler_height", "");

                    g_iShow=(integer)llList2String(lSettings,2);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "titler_show="+(string)g_iShow, "");
                } else if(llList2String(lSettings,1) == "plain"){
                    g_iNoB64 = TRUE;
                    llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "ALL", "");
                }
                Titler();
            }
        
        }else if(iNum == LM_SETTING_EMPTY){
            
            //integer ind = llListFindList(g_lSettingsReqs, [sStr]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
        } else if(iNum == LM_SETTING_DELETE){
            list lPar = llParseString2List(sStr, ["_"],[]);
            string sToken = llList2String(lPar,0);
            string sVar = llList2String(lPar,1);
            
            //integer ind = llListFindList(g_lSettingsReqs, [sStr]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            if(sToken=="global")
                if(sVar == "locked") g_iLocked=FALSE;
        } else if(iNum == REBOOT && sStr == "reboot")  llResetScript();
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}