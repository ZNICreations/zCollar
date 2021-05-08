    
/*
This file is a part of zCollar.
Copyright ©2021


: Contributors :

Aria (Tashia Redrose)
    * May 2021          -       Rebranded as zc_cuff_pose
    * February 2021       -       Created oc_cuff_pose
      
      
et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/ZNICreations/zCollar

*/ 
#include "MasterFile.lsl"


/// 
/// FROM SL WIKI http://wiki.secondlife.com/wiki/Combined_Library#Replace
///
string str_replace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str = "") + str, [search], []), replace);
}

list g_lPoseMap = [];

string g_sPendingPose;
string g_sPendingAnim;
string g_sPendingChains;
string g_sPendingRLV;
string g_sPendingAge;
string g_sPendingGravity;


string g_sPendingAnims;
string g_sPendingCollarChains;
string g_sPoseName= "";
string g_sActivePose="";

list g_lCollarMap = [];



Link(string sPkt, integer iNum, string sMsg, key kID)
{
    llMessageLinked(LINK_SET, 999, llList2Json(JSON_OBJECT, ["pkt", sPkt, "iNum", iNum, "sMsg", sMsg, "kID", kID]), "");
}
StartCuffPose(list lParams, integer iSave)
{
    if(iSave)Link("from_addon", LM_SETTING_SAVE, "zccuffs_"+g_sPoseName+"pose="+llList2String(lParams,0), "");
    
    //llSay(0, ".\nENTER StartCuffPose(list[], int)\n{\n\targ0 = "+llDumpList2String(lParams," ~ ")+"\n\targ1 = "+(string)iSave+"\n}\n\nAnimation = "+llList2String(lParams,1));
    llStartAnimation(llList2String(lParams,1));
    
    // param 2 = chain options
    list opts = llParseString2List(llList2String(lParams,2), ["~"],[]);
    Summon(opts, llList2String(lParams,4), llList2String(lParams,3));
}


Desummon(list lPoints)
{
    integer ix=0;
    integer end = llGetListLength(lPoints);
    for(ix=0;ix<end;ix++){
        list tmp = llParseString2List(llList2String(lPoints,ix),["="],[]);
        Link("from_addon", DESUMMON_PARTICLES, llList2String(tmp,0), "");
    }
}

Summon(list opts, string age, string gravity)
{
    
    integer i=0;
    integer end = llGetListLength(opts);
    for(i=0;i<end;i++){
        // loop over and send out SUMMON_PARTICLES
        list tmp = llParseString2List(llList2String(opts,i), ["="],[]);
        Link("from_addon", SUMMON_PARTICLES, llList2String(tmp,0)+"|"+llList2String(tmp,1)+"|"+age+"|"+gravity, "");
    }
}
string g_sCurrentPose = "NONE";
default
{
    state_entry(){
        llOwnerSay(llGetScriptName()+" ready ("+(string)llGetFreeMemory()+"b)");
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
    }
    
    
    link_message(integer iSender, integer iNum, string sMsg, key kID)
    {
        if(iNum==-1){
            llResetScript();
        } else if(iNum == 1){
            // READ NOTECARD REQUEST
            if(kID=="read_poses"){
                g_sPoseName=sMsg;
                g_sPoseName = llToLower(str_replace(g_sPoseName, " ", ""));
                g_sPoseName = llToLower(str_replace(g_sPoseName, "_", ""));
                g_sPoseName = llToLower(str_replace(g_sPoseName, "=", ""));
                g_sPoseName = llToLower(str_replace(g_sPoseName, "~", ""));
                g_lPoseMap=[];
            }
            if(kID=="read_collar")g_lCollarMap=[];
            //llSay(0, "sub dataserver call: "+(string)kID);
            UpdateDSRequest(NULL, llGetNotecardLine(sMsg,0), (string)kID+":0:"+sMsg);
        } else if(iNum == 300)
        {
            
            integer bSummon = FALSE;
            if(g_sActivePose != "" && g_sActivePose!= sMsg)
            {
                // chains must be summoned
                bSummon=TRUE;
            }else if(g_sActivePose==""){
                if(sMsg==""){
                    bSummon=FALSE;
                }else bSummon=TRUE;
            }
                                
            if(bSummon)
            {
                // check if needing to desummon, then summon particles
                if(g_sActivePose!="")
                {
                    integer index=llListFindList(g_lCollarMap,[g_sActivePose]);
                    if(index!=-1)
                    {
                        
                        llMessageLinked(LINK_SET, 401, llList2String(g_lCollarMap, index+1), "");
                        //Desummon(llParseString2List(llList2String(g_lCollarMap, index+1), ["~"],[]));
                    }
                }
                g_sActivePose=sMsg;
                integer ind = llListFindList(g_lCollarMap, [g_sActivePose]);
                if(ind!=-1){
                    //llSay(0, "Summoning particles for collar map: "+sVal+" = (chains) "+llList2String(g_lCollarMap,ind+1));
                    llMessageLinked(LINK_SET, 400, llList2String(g_lCollarMap, ind+1), "3|-0.076");
                    //Summon(llParseString2List(llList2String(g_lCollarMap, ind+1), ["~"],[]),"3","-0.076");
                }else{
                    //llSay(0, "Collar Mapping not found for animation: "+sVal);
                }
            }
        } else if(iNum==301)
        {
            
            integer index=llListFindList(g_lCollarMap, [g_sActivePose]);
            if(index!=-1){
                //Desummon(llParseString2List(llList2String(g_lCollarMap,index+1),["~"],[]));
                llMessageLinked(LINK_SET, 401, llList2String(g_lCollarMap, index+1), "");
            }
            g_sActivePose="";
            
        } else if(iNum == 9)
        {
            // Send back pose menu button list
            llMessageLinked(LINK_SET, 10, llDumpList2String(StrideOfList(g_lPoseMap, 6, 0,-1), "`"), sMsg+"^"+(string)kID);
        } else if(iNum == 500)
        {
            integer index=llListFindList(g_lPoseMap, [sMsg]);
            g_sCurrentPose=sMsg;
            //llSay(0, "Pose Map scan - only start animation ("+sMsg+") = "+(string)index);
            if(index!=-1)StartCuffPose(llList2List(g_lPoseMap, index,index+5), (integer)((string)kID));
        } else if(iNum == 501)
        {
            integer index=llListFindList(g_lPoseMap, [sMsg]);
            list lMap = llList2List(g_lPoseMap, index,index+5);
                                 
            //llSay(0, "Pose Map scan pose change ("+sMsg+"/"+g_sCurrentPose+") = "+(string)index);
            if(g_sCurrentPose!="NONE"){  
                integer indx = llListFindList(g_lPoseMap, [g_sCurrentPose]); 
                list lPoints = llParseString2List(llList2String(g_lPoseMap, indx+2),["~"],[]);
                Desummon(lPoints);
                Link("from_addon", TIMEOUT_REGISTER, "2", g_sPoseName+"playback:"+llStringToBase64(llDumpList2String(lMap, "~~~")));
                //llSay(0, "Pose selection: "+sMsg+"\nPose params dump: "+llDumpList2String(lMap, ", "));
                string curAnim = llList2String(g_lPoseMap, llListFindList(g_lPoseMap, [g_sCurrentPose])+1);
                g_sCurrentPose="NONE";
                llStopAnimation(curAnim);
                return;
            }
            g_sCurrentPose = sMsg;
            StartCuffPose(lMap,TRUE);
        } else if(iNum == 505)
        {
            
            integer index=llListFindList(g_lPoseMap, [sMsg]);
            list lPoints = llParseString2List(llList2String(g_lPoseMap, index+2),["~"],[]);
            Desummon(lPoints);
            string curAnim = llList2String(g_lPoseMap, index+1);
            g_sCurrentPose="NONE";
            llStopAnimation(curAnim);
        } else if(iNum == 509){ // Signal used to clear the flags in the event of the cuffs being hidden, since no particles should be visible if hidden
            if(g_sCurrentPose!="NONE"){
                integer index=llListFindList(g_lPoseMap, [g_sCurrentPose]);
                list lPoints = llParseString2List(llList2String(g_lPoseMap, index+2),["~"],[]);
                Desummon(lPoints);
                string curAnim = llList2String(g_lPoseMap, index+1);
                g_sCurrentPose="NONE";
                llStopAnimation(curAnim);
            }
            
            if(g_sActivePose != ""){
                g_sActivePose="";
            }
        }
    }
    
    dataserver(key kID, string sData)
    {
        if(HasDSRequest(kID)!=-1)
        {
            list lMeta = llParseString2List(GetDSMeta(kID), [":"],[]);
            //llSay(0, "sub/dataserver (sData: "+sData+")\nMeta: "+GetDSMeta(kID));
            if(llList2String(lMeta,0)=="read_poses"){
                if(sData==EOF){
                    DeleteDSReq(kID);
                    
                    g_lPoseMap += [g_sPendingPose, g_sPendingAnim, g_sPendingChains, g_sPendingRLV, g_sPendingAge, g_sPendingGravity];
                    
                    
                    //llWhisper(0, "Pose Configuration finished reading : Poses = "+llDumpList2String( llList2ListStrided(g_lPoseMap,0,-1,5), ", ") );

                    //llWhisper(0, "Clearing all particle systems");
                    llMessageLinked(LINK_SET, 0, "", "");
                    //ClearAllParticles();
                    //llWhisper(0, "Particles stopped.");
                    //llWhisper(0, "Perform check for cuff script update");

                    llMessageLinked(LINK_SET,2,"","");
                    //llSay(0, "Cuff ready");
                } else{
                    integer iLine = (integer)llList2String(lMeta,1);
                    string sPoses = llList2String(lMeta,2);
                    iLine++;
                    list lPara = llParseString2List(sData,[":"],[]);
                    if(llList2String(lPara,0) == "PoseName"){
                        if(g_sPendingPose != ""){
                            g_lPoseMap += [g_sPendingPose, g_sPendingAnim, g_sPendingChains, g_sPendingRLV, g_sPendingAge, g_sPendingGravity];
                        }
                        
                        g_sPendingPose=llList2String(lPara,1);
                    } else if(llList2String(lPara,0) == "PoseAnim"){
                        g_sPendingAnim = llList2String(lPara,1);
                    } else if(llList2String(lPara,0) == "PoseChains"){
                        g_sPendingChains = llList2String(lPara,1);
                    } else if(llList2String(lPara,0) == "PoseRestrictions"){
                        g_sPendingRLV = llList2String(lPara,1);
                    } else if(llList2String(lPara,0) == "PoseAge"){
                        g_sPendingAge = llList2String(lPara,1);
                    } else if(llList2String(lPara,0)=="PoseGravity"){
                        g_sPendingGravity = llList2String(lPara,1);
                    }
                    
                    UpdateDSRequest(kID, llGetNotecardLine(sPoses, iLine), "read_poses:"+(string)iLine+":"+sPoses);
                }
            } else if(llList2String(lMeta,0)=="read_collar")
            {
                if(sData!=EOF){
                    integer iLine = (integer)llList2String(lMeta,1);
                    iLine++;
                    string note = llList2String(lMeta,2);
                    
                    
                    // parse the line
                    list lTmp = llParseString2List(sData,[" = "],["[","]"]);
                    if(llList2String(lTmp,0)=="[" && llList2String(lTmp,-1)=="]")
                    {
                        if(g_sPendingAnims == "")g_sPendingAnims = llList2String(lTmp,1);
                        else{
                            list lTmps = llParseString2List(g_sPendingAnims, ["|"],[]);
                            integer ix=0;
                            integer xend = llGetListLength(lTmps);
                            for(ix=0;ix<xend;ix++){
                                //llSay(0, "Collar Pose Mapping added (S): "+llList2String(lTmps,ix)+" = (chains) "+g_sPendingCollarChains);
                                g_lCollarMap += [llList2String(lTmps,ix), g_sPendingCollarChains];
                            }
                            g_sPendingAnims = llList2String(lTmp,1);
                        }
                    } else if(llList2String(lTmp,0)=="Chains")
                    {
                        g_sPendingCollarChains = llList2String(lTmp,1);
                    }
                
                
                    UpdateDSRequest(kID, llGetNotecardLine(note, iLine), "read_collar:"+(string)iLine+":"+note);
                }else{
                    DeleteDSReq(kID);
                    
                    list lTmps = llParseString2List(g_sPendingAnims, ["|"],[]);
                    integer ix=0;
                    integer xend = llGetListLength(lTmps);
                    for(ix=0;ix<xend;ix++){
                        //llSay(0, "Collar Pose Mapping added (EOF): "+llList2String(lTmps,ix)+" = (chains) "+g_sPendingCollarChains);
                        g_lCollarMap += [llList2String(lTmps,ix), g_sPendingCollarChains];
                    }
                }
            }
        }
    }
}
