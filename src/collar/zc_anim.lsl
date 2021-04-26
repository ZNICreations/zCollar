/*
This file is a part of zCollar.
Copyright 2021

: Contributors :

Aria (Tashia Redrose)
    * April 2021        -   Rebranded as zc_anim
    * July 2020         - Rewrote oc_anim
    * Dec 2020          - Fix bug where animations were not treated case insensitive, and where animations with a space in the name could not be played by chat command or menu button
    * Feb 2021          - Fix Public Access
    
Felkami (Caraway Ohmai)
    * Dec 2020          - Fixed #456, #462, #461, added LockMeister AO suppress

et al.


Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/
#include "MasterFile.lsl"

string g_sParentMenu = "Main";
string g_sSubMenu = "Animations";

integer g_iIsMoving;


list g_lAdditionalButtons=[];



Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

list g_lCurrentAnimations=[];

string setor(integer iTest, string sTrue, string sFalse){
    if(iTest)return sTrue;
    else return sFalse;
}

integer g_iAnimLock=FALSE;
integer g_iPosture = FALSE;

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Animations]\n\nCurrent Animation: "+setor((g_lCurrentAnimations==[]), "None", llList2String(g_lCurrentAnimations, 0)+"\nCurrent Pose: "+setor((g_sPose==""), "None", g_sPose));
    list lButtons = [Checkbox(g_iAnimLock,"AnimLock"), "Pose"];
    
    if(llGetInventoryType("~stiff")==INVENTORY_ANIMATION){
        lButtons += [Checkbox(g_iPosture, "Posture")];
    }else {
        sPrompt += "\n\n* Posture is only available if you have the ~stiff animation in inventory of the collar";
    }
    Dialog(kID, sPrompt, lButtons+g_lAdditionalButtons, [UPMENU], 0, iAuth, "Menu~Animations");
}


PoseMenu(key kID, integer iAuth, integer iPage){
    string sPrompt = "\n[Pose Menu]\n\nCurrent Animation: "+setor((g_sPose==""), "None", g_sPose);
    sPrompt += "\nCurrent Height Adjustment: ";
    if(g_lCurrentAnimations==[])sPrompt+=(string)g_fStandHover;
    else{
        integer iPos = llListFindList(g_lAdjustments, [g_sPose]);
        if(iPos==-1)sPrompt += "0";
        else sPrompt += llList2String(g_lAdjustments,iPos+1);
    }
    Dialog(kID, sPrompt, GetPoseList(-1), [ UP_ARROW, DOWN_ARROW, "STOP",UPMENU], iPage, iAuth, "Animations~Poses");
}

list GetPoseList(integer iType)
{
    // -1 = as it exists in inventory
    // 0 = lower case
    
    list lTmp;
    integer i=0;
    integer end = llGetInventoryNumber(INVENTORY_ANIMATION);
    for(i=0;i<end;i++){
        
        string name = llGetInventoryName(INVENTORY_ANIMATION, i);
        if(llGetSubString(name,0,0)!="~"){
            if(iType == -1)lTmp += [name];
            else lTmp += [llToLower(name)];
        }
    }
    
    return lTmp;
}

UserCommand(integer iNum, string sStr, key kID) {
    string ssStr = llToLower(sStr);
    if (iNum & C_OWNER && ssStr == "runaway") {
        g_lOwner = g_lTrust = g_lBlock = [];
        return;
    }
    if (ssStr==llToLower(g_sSubMenu) || ssStr == "menu "+llToLower(g_sSubMenu)) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        list lTmp = llParseString2List(sStr, [" "],[]);
        //integer iWSuccess = 0; 
        string sChangetype = llList2String(lTmp,0);
        string sChangevalue = llList2String(lTmp,1);
        integer iPageNum = llList2Integer(lTmp,2);
        integer iRespringPoses=FALSE;
        
        if(llSubStringIndex(sStr,"remenu") != -1){
            integer len = llGetListLength(lTmp);
            len = len-3;
            sChangetype = llDumpList2String(llList2List(lTmp, 0,len), " ");
            sChangevalue = llList2String(lTmp, len+1);
            iPageNum = llList2Integer(lTmp, len+2);
            
            //llSay(0, "anim remenu: "+sStr+";;;; "+sChangetype+";"+sChangevalue+";"+(string)iPageNum);
        }
        //string sText;
        //llOwnerSay("usercommand: "+sStr+"; "+sChangetype+"; "+sChangevalue);
        if(g_iAnimLock && kID == g_kWearer && (llGetInventoryType(sChangetype)!=INVENTORY_NONE)) {
            llMessageLinked(LINK_SET, NOTIFY,"0%NOACCESS% to changing animations", g_kWearer);
            jump checkRemenu;
        }
        if(llListFindList(GetPoseList(0),[llToLower(sChangetype)])!=-1){
            // this is a pose
            if (g_sPose != "")StopAnimation(g_sPose);
            // get actual pose name as it exists in inventory
            integer index = llListFindList(GetPoseList(0), [llToLower(sChangetype)]);
            g_sPose = llGetInventoryName(INVENTORY_ANIMATION,index);
            StartAnimation(g_sPose);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "anim_pose="+llList2String(g_lCurrentAnimations, 0),"");
            iRespringPoses=TRUE;
        } else if(llToLower(sChangetype) == "stop" || llToLower(sChangetype)=="release"){
            if(g_iAnimLock && kID == g_kWearer){
                llMessageLinked(LINK_SET,NOTIFY,"0%NOACCESS% to stopping animation", g_kWearer);
                jump checkRemenu;
            }
            if (g_sPose != ""){
                StopAnimation(g_sPose);
                g_sPose = "";
            }
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, "anim_pose","");
            iRespringPoses=TRUE;
        } else if(sChangetype == UP_ARROW || sChangetype == "up" || sChangetype == DOWN_ARROW || sChangetype == "down"){
            // only owner or wearer
            if(iNum &(C_OWNER|C_WEARER|C_TRUSTED)){
                // adjust current pose
                //llOwnerSay(" up or down");
                //sChangevalue="remenu";
                integer iUp= FALSE;
                iRespringPoses=TRUE;
                if(sChangetype == UP_ARROW || sChangetype == "up")iUp=TRUE;
                if(g_lCurrentAnimations == []){
                    // adjust standing
                    //llOwnerSay("up: "+(string)iUp+"; anims list blank");
                    if(iUp)g_fStandHover += g_fAdjustment;
                    else g_fStandHover-=g_fAdjustment;
                    if(g_fStandHover==0)llMessageLinked(LINK_SET,LM_SETTING_DELETE,"offset_standhover","");
                    else llMessageLinked(LINK_SET, LM_SETTING_SAVE, "offset_standhover="+(string)g_fStandHover,"");
                    llMessageLinked(LINK_SET, NOTIFY, "0The hover height for 'Standing' is now "+(string)g_fStandHover, g_kWearer);
                } else {
                    integer iPos=llListFindList(g_lAdjustments,llList2List(g_lCurrentAnimations, 0, 0));
                    if(iPos==-1){
                       // llOwnerSay("up:"+(string)iUp+"; anim not found in adjustments");
                        // OK now we make a new entry
                        
                        if(iUp)
                            g_lAdjustments+=[llList2String(g_lCurrentAnimations, 0), g_fAdjustment];
                        else
                            g_lAdjustments+=[llList2String(g_lCurrentAnimations, 0),-g_fAdjustment];
                            
                        
                        llMessageLinked(LINK_SET, NOTIFY, "0The hover height for '"+llList2String(g_lCurrentAnimations, 0)+"' is now "+(string)g_fAdjustment, g_kWearer);
                    } else {
                        
                        //llOwnerSay("up:"+(string)iUp+"; anim update");
                        float fCurrent = (float)llList2String(g_lAdjustments, iPos+1);
                        if(iUp)
                            fCurrent+=g_fAdjustment;
                        else
                            fCurrent -= g_fAdjustment;
                        
                        
                        llMessageLinked(LINK_SET, NOTIFY, "0The hover height for '"+llList2String(g_lCurrentAnimations, 0)+"' is now "+(string)fCurrent, g_kWearer);
                        if(fCurrent!=0)
                            g_lAdjustments = llListReplaceList(g_lAdjustments, [fCurrent],iPos+1,iPos+1);
                        else
                            g_lAdjustments = llDeleteSubList(g_lAdjustments,iPos,iPos+1);
                    }
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "offset_hovers="+llDumpList2String(g_lAdjustments,","),"");
                    
                    //llOwnerSay("up:"+(string)iUp+"; saved hover list");
                    if(llGetListLength(g_lCurrentAnimations)!=0)
                        PlayAnimation();
                    
                    
                }
            }else llMessageLinked(LINK_SET, NOTIFY, "%NOACCESS% to changing height", kID);
        } else if(sChangetype == "animlock"){
            string text;
            if(iNum & C_OWNER){
                //g_iAnimLock=1-g_iAnimLock;
                g_iAnimLock = !(g_iAnimLock);
                if(g_iAnimLock)
                    llMessageLinked(LINK_SET,LM_SETTING_SAVE, "anim_animlock="+(string)g_iAnimLock,"");
                else
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "anim_animlock","");
                text = "0Animation lock updated";
            } else text = "0%NOACCESS% to change animation lock";
            
            if(sChangevalue == "remenu") Menu(kID,iNum);
            else llMessageLinked(LINK_SET, NOTIFY, text, kID);
        } else if(llToLower(sChangetype) == "pose"){
            PoseMenu(kID, iNum,0);
        } else if(llToLower(sChangetype) == "menu" && llToLower(sChangevalue) == "pose"){
            PoseMenu(kID, iNum,0);
        } else if(llToLower(sChangetype) == "posture"){
            if(iNum & C_OWNER){
                if(sChangevalue=="off"){
                    llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "anim_posture=0", "");
                    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "anim_posture", "");
                }else if(sChangevalue=="on"){
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "anim_posture=1", "");
                }
            } else llMessageLinked(LINK_SET,NOTIFY,"0%NOACCESS% to toggling posture", kID);
            
        }
        
        @checkRemenu;
        if(sChangevalue == "remenu" && iRespringPoses)PoseMenu(kID,iNum, iPageNum);
        //else if(sChangevalue == "remenu" && !iRespringPoses)Menu(kID, iNum);

    }
}

integer g_iPermissionGranted=FALSE;
key g_kWearer;
list g_lOwner;
list g_lTrust;
list g_lBlock;
integer g_iLocked=FALSE;
float g_fStandHover=0;
list g_lAdjustments;
float g_fAdjustment = 0.02;
integer g_iStoppedAdjust;
string g_sPose = "";

MessageAOs(string sONOFF) { // send string as "ON" / "OFF" saves 2 llToUpper
    llRegionSayTo(g_kWearer, -8888, (string)g_kWearer + "boot" + llToLower(sONOFF)); // for Firestorm AO
}

integer g_iTimerMode;
integer TIMER_START_ANIMATION =1;
MoveStart(){
    if(g_lCurrentAnimations!=[]){
        if(!g_iStoppedAdjust){
            MessageAOs("on"); //Enable AO's for walk animation
            llStopAnimation(llList2String(g_lCurrentAnimations, 0));
            llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;0=force",g_kWearer);
        }
        g_iStoppedAdjust=TRUE;
        llResetTime();
    }
}

MoveEnd(){
    //We don't need to disable AO's like we do for MoveStart(). PlayAnimation will be called eventually
    if(g_iLeashMove)return;
    if(g_iPermissionGranted){
        if(g_lCurrentAnimations==[]){
            if (g_fStandHover != 0.0)
                llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;"+(string)g_fStandHover+"=force",g_kWearer);
        }else{
            g_iTimerMode = TIMER_START_ANIMATION;
            llResetTime();
            // wait a few seconds before restarting the animation
            llSetTimerEvent(1);
            g_iStoppedAdjust=FALSE;
        }
    }
    // should we set the timer if we don't have permissions yet?
}

PlayAnimation(){
    // plays g_lCurrentAnimations[0] and makes adjustments
    if(g_lCurrentAnimations==[])return;
    // i think we must just try to start it even if it may already be playing.
    if(g_iPermissionGranted){
        MessageAOs("off");
        llStartAnimation(llList2String(g_lCurrentAnimations, 0));
        integer iPos = llListFindList(g_lAdjustments,llList2List(g_lCurrentAnimations, 0, 0));
        if(iPos!=-1){
            llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;"+llList2String(g_lAdjustments,iPos+1)+"=force",g_kWearer);
        }
        g_iTimerMode = 0;
    }else{
        g_iTimerMode = TIMER_START_ANIMATION;
        llSetTimerEvent(1);
    }
}

StopAnimation(string anim){
    if(g_lCurrentAnimations==[])return;
    integer aPos = llListFindList(g_lCurrentAnimations, [anim]);
    if (aPos == -1)return;
    if (aPos == 0){
        MessageAOs("on");
        llStopAnimation(llList2String(g_lCurrentAnimations, 0));
    }
    g_lCurrentAnimations = llDeleteSubList(g_lCurrentAnimations, aPos, aPos);
    if (aPos == 0){
        if (g_lCurrentAnimations == []){
            if(g_fStandHover!=0)llMessageLinked(LINK_SET,RLV_CMD, "adjustheight:1;0;"+(string)g_fStandHover+"=force", g_kWearer);
            else llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;0=force",g_kWearer);
        }else PlayAnimation();
    }
}

StopAllAnimations(){
    if(g_lCurrentAnimations==[])return;
    llStopAnimation(llList2String(g_lCurrentAnimations, 0));
    g_lCurrentAnimations = [];
    g_sPose = "";
    if(g_fStandHover!=0)llMessageLinked(LINK_SET,RLV_CMD, "adjustheight:1;0;"+(string)g_fStandHover+"=force", g_kWearer);
    else llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;0=force",g_kWearer);
}


StartAnimation(string anim){
    if(llGetInventoryType(anim)!=INVENTORY_ANIMATION)return;//fail
    integer anim_count = llGetListLength(g_lCurrentAnimations);
    if (anim_count == 30)return;//fail
    if(anim_count)llStopAnimation(llList2String(g_lCurrentAnimations, 0));
    // if we have it in the stack, let's move it to top
    integer aPos = llListFindList(g_lCurrentAnimations, [anim]);
    if (aPos == -1){
        g_lCurrentAnimations = [anim] + g_lCurrentAnimations;
    }else{
        g_lCurrentAnimations = [anim] + llDeleteSubList(g_lCurrentAnimations, aPos, aPos);
    }
    PlayAnimation();
}
integer g_iLeashMove=FALSE;



RunPosture(){
    if(g_iPosture){
        if(llGetInventoryType("~stiff")==INVENTORY_ANIMATION)
            llStartAnimation("~stiff");
    }else {
        if(llGetInventoryType("~stiff")==INVENTORY_ANIMATION)
            llStopAnimation("~stiff");
    }
}
default
{
    on_rez(integer iNum){
        llResetScript();
    }
    state_entry(){
        if(llGetStartParameter()!=0)state inUpdate;
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
    on_rez(integer iNum){
        llResetScript();
    }
    state_entry()
    {
        g_kWearer = llGetOwner();

        llRequestPermissions(g_kWearer, PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS);
    }
    
    changed(integer t){
        if(t&CHANGED_INVENTORY)llResetScript(); // maybe changed animations
    }
    
    run_time_permissions(integer iPerms){
        // Check if both permissions granted
        if(iPerms& PERMISSION_OVERRIDE_ANIMATIONS && iPerms&PERMISSION_TRIGGER_ANIMATION && iPerms&PERMISSION_TAKE_CONTROLS){
            g_iPermissionGranted=TRUE;
            llTakeControls(
                CONTROL_FWD |
                CONTROL_BACK |
                CONTROL_LEFT |
                CONTROL_RIGHT |
                CONTROL_ROT_LEFT |
                CONTROL_ROT_RIGHT |
                CONTROL_UP |
                CONTROL_DOWN |
                CONTROL_ML_LBUTTON | 
                0x02 |
                0x04,
                TRUE,TRUE);
        }
    }
    
    timer(){
        if(g_iLeashMove)return;
        string sAnim = llGetAnimation(g_kWearer);
        if(sAnim == ""){
            // Avatar is logging out. Goodbye!
            llSetTimerEvent(FALSE);
            return;
        }
        
        if(sAnim == "Falling Down" || sAnim == "Jumping" || sAnim == "Landing" || sAnim == "Soft Landing"){
            llResetTime();
        }
        
        if(llGetTime()>30.0)llSetTimerEvent(FALSE);
        
        if(g_iTimerMode == TIMER_START_ANIMATION && llGetTime()>2.5){
            if(g_lCurrentAnimations==[]){
                if(g_fStandHover != 0) llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;"+(string)g_fStandHover,g_kWearer);
            }else PlayAnimation();
            llSetTimerEvent(FALSE);
        }
    }
    
    control(key kID, integer iLevel, integer iEdge){
        if(iLevel == 0){
            // all movement has ceased
            MoveEnd();
        } else {
            MoveStart();
        }
                
        //integer iStart = iLevel & iEdge;
        //integer iEnd = ~iLevel & iEdge;
        //integer iHeld = iLevel & ~iEdge;
        //integer iUntouched = ~(iLevel | iEdge);
        
        //llWhisper(0, "controls: "+llDumpList2String([iLevel, iEdge, iStart, iEnd, iHeld, iUntouched], ", "));
    }
    
    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum ==COMMAND) {
            list lTmp = llParseString2List(sStr,["|>"],[]);
            integer iMask = (integer)llList2String(lTmp,0);
            if(!(iMask&(C_OWNER|C_PUBLIC|C_TRUSTED|C_GROUP|C_WEARER)))return;
            string sCmd = llList2String(lTmp,1);
            UserCommand(iMask, sCmd, kID);
        }
        else if(iNum == MENUNAME_REQUEST && sStr == g_sParentMenu){
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu+"|"+ g_sSubMenu,"");
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
        }else if(iNum == MENUNAME_RESPONSE){
            list ltmp = llParseString2List(sStr,["|"],[]);
            if(llList2String(ltmp,0) == g_sSubMenu){
                if(llListFindList(g_lAdditionalButtons,[llList2String(ltmp,1)])==-1)g_lAdditionalButtons+=llList2String(ltmp,1);
            }
        } else if(iNum == MENUNAME_REMOVE){
            list ltmp = llParseString2List(sStr,["|"],[]);
            if(llList2String(ltmp,0) == g_sSubMenu){
                integer iPos=llListFindList(g_lAdditionalButtons,[llList2String(ltmp,1)]);
                if(iPos!=-1)g_lAdditionalButtons = llDeleteSubList(g_lAdditionalButtons, iPos,iPos);
            }
        }
        else if(iNum == DIALOG_RESPONSE){
        

            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iPage = llList2Integer(lMenuParams,2);
                integer iAuth = llList2Integer(lMenuParams,3);
                integer iRespring = TRUE;
                
                if(sMenu == "Menu~Animations"){
                    if(sMsg == UPMENU) {
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, CMD_ZERO, "menu "+g_sParentMenu, kAv);
                    }
                    else if(sMsg == Checkbox(g_iAnimLock, "AnimLock")){
                        llMessageLinked(LINK_SET,CMD_ZERO,"animlock remenu "+(string)iPage, kAv);
                        iRespring=FALSE;
                    }
                    else if(sMsg == "Pose"){
                        PoseMenu(kAv,iAuth, 0);
                        iRespring=FALSE;
                    } else if(sMsg == Checkbox(g_iPosture,"Posture")){
                        if(iAuth & C_OWNER){
                            if(g_iPosture){
                                g_iPosture=0;
                                llMessageLinked(LINK_SET, CMD_ZERO, "posture off",kAv);
                            }
                            else {
                                g_iPosture=1;
                                llMessageLinked(LINK_SET, CMD_ZERO, "posture on",kAv);
                            }
                        }
                        
                    }else {
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, COMMAND, (string)iAuth+ "|>menu "+sMsg,kAv);
                    }

                    if(iRespring)Menu(kAv,iAuth);
                } else if(sMenu == "Animations~Poses"){
                    if(sMsg == UPMENU){
                        iRespring=FALSE;
                        llMessageLinked(LINK_SET, COMMAND, (string)iAuth+"|>menu "+g_sSubMenu, kAv);
                    
                    } else {
                        // Set standing animation
                        llMessageLinked(LINK_SET, CMD_ZERO, sMsg + " remenu "+(string)iPage, kAv);
                        iRespring=FALSE;
                    }


                    if(iRespring)PoseMenu(kAv,iAuth, iPage);
                }
            }
            
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if(iNum == LM_SETTING_RESPONSE){
            // Detect here the Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);
            string sTok = llList2String(lSettings,0);
            string sVar = llList2String(lSettings,1);
            string sVal = llList2String(lSettings,2);
            
            //integer ind = llListFindList(g_lSettingsReqs, [sTok + "_" + sVar]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            if(sTok=="global"){
                if(sVar=="locked"){
                    g_iLocked=(integer)sVal;
                } else if(sVar == "checkboxes"){
                    g_lCheckboxes = llParseString2List(sVal,[","],[]);
                }
            } else if(sTok == "anim"){
                if(sVar == "pose"){
                    if (g_sPose != "")StopAnimation(g_sPose);
                    g_sPose = sVal;
                    StartAnimation(sVal);
                } else if(sVar == "animlock"){
                    g_iAnimLock = (integer)sVal; // <-- used incase its set in .settings to false for some reason
                } else if(sVar == "posture"){
                    g_iPosture=(integer)sVal;
                    RunPosture();
                }
            } else if(sTok == "offset"){
                if(sVar == "hovers"){
                    g_lAdjustments = llParseString2List(sVal,[","],[]);
                } else if(sVar == "standhover"){
                    g_fStandHover = (float)sVal;
                    if(g_fStandHover!=0)llMessageLinked(LINK_SET,RLV_CMD, "adjustheight:1;0;"+(string)g_fStandHover+"=force", g_kWearer);
                    else llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;0=force",g_kWearer);
                }
            }
        } else if(iNum == LM_SETTING_DELETE){
            // This is recieved back from settings when a setting is deleted
            list lSettings = llParseString2List(sStr, ["_"],[]);
            string sTok = llList2String(lSettings,0);
            string sVar = llList2String(lSettings,1);
            
            //integer ind = llListFindList(g_lSettingsReqs, [sStr]);
            //if(ind!=-1)g_lSettingsReqs = llDeleteSubList(g_lSettingsReqs, ind,ind);
            
            
            if(sTok=="global"){
                if(sVar == "locked") g_iLocked=FALSE;
            }else if(sTok == "anim"){
                if(sVar == "pose"){
                    if (g_sPose != ""){
                        StopAnimation(g_sPose);
                        g_sPose = "";
                    }
                } else if(sVar == "animlock")g_iAnimLock=FALSE;
                else if(sVar == "posture"){
                    g_iPosture=FALSE;
                    RunPosture();
                }
            } else if(sTok == "offset"){
                if(sVar == "hovers"){
                    g_lAdjustments=[];
                } else if(sVar == "standhover"){
                    g_fStandHover = 0;
                    llMessageLinked(LINK_SET, RLV_CMD, "adjustheight:1;0;0=force",g_kWearer);
                }
            }
        } else if(iNum == LEASH_START_MOVEMENT){
            g_iStoppedAdjust=FALSE;
            g_iLeashMove=TRUE;
            MoveStart();
        } else if(iNum == LEASH_END_MOVEMENT){
            g_iLeashMove=FALSE;
            MoveEnd();
        } else if(iNum == ANIM_START){
            StartAnimation(sStr);
        } else if(iNum == ANIM_STOP){
            StopAnimation(sStr);
        } else if (iNum == ANIM_LIST_REQ){
            llMessageLinked(LINK_SET, ANIM_LIST_RES, llDumpList2String(GetPoseList(0), "|"), "");
        } else if(iNum == REBOOT){
            StopAllAnimations();
            llResetScript();
        }
        //llOwnerSay(llDumpList2String([iSender,iNum,sStr,kID],"^"));
    }
}



state inUpdate{
    link_message(integer iSender, integer iNum, string sMsg, key kID){
        if(iNum == REBOOT){
            StopAllAnimations();
            llResetScript();
        }else if(iNum == 0){
            if(sMsg == "do_move" && !g_iIsMoving){
                
                if(llGetLinkNumber()==LINK_ROOT || llGetLinkNumber() == 0)return;
                
                g_iIsMoving=TRUE;
                llOwnerSay("Moving oc_anim!");
                integer i=0;
                integer end=llGetInventoryNumber(INVENTORY_ALL);
                for(i=0;i<end;i++){
                    string item = llGetInventoryName(INVENTORY_ALL,i);
                    if(llGetInventoryType(item)==INVENTORY_SCRIPT && item!=llGetScriptName()){
                        llRemoveInventory(item);
                    }else if(llGetInventoryType(item)!=INVENTORY_SCRIPT){
                        if (llGetInventoryPermMask( item, MASK_OWNER ) & PERM_COPY){
                            llGiveInventory(kID, item);
                            llRemoveInventory(item);
                            i=-1;
                            end=llGetInventoryNumber(INVENTORY_ALL);
                        } else {
                            llOwnerSay("Item '"+item+"' is no-copy and can not be moved! Please move it manually!");
                        }
                    }
                }
                
                llRemoveInventory(llGetScriptName());
            }
        }
    }
}
