 
string COLLAR_VERSION = "10.0.0001"; // Provide enough room

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer TIMEOUT_READY = 30497;
integer TIMEOUT_REGISTER = 30498;
integer TIMEOUT_FIRED = 30499;


integer NOTIFY = 1002;
integer NOTIFY_OWNERS=1003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed
//MESSAGE MAP
integer AUTH_REQUEST = 600;
integer AUTH_REPLY=601;

integer CMD_ZERO = 0;
/*integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_BLOCKED = 598; // <--- Used in auth_request, will not return on a CMD_ZERO
integer CMD_NOACCESS=599;*/

integer CMD_SAFEWORD = 510;
integer CMD_RELAY_SAFEWORD = 511;
integer CMD_RLV_RELAY = 507;
integer COMMAND = 512; // New channel for authorized commands
integer C_OWNER = 1;
integer C_TRUSTED = 2;
integer C_WEARER = 4;
integer C_GROUP = 8;
integer C_BLOCKED = 16;
integer C_PUBLIC = 32;
// Not implemented commands: SUPPORT , COLLAR_INTERNALS
integer C_SUPPORT = 64;
integer C_COLLAR_INTERNALS = 128; // TODO: Runaway and other internal commands that should be handled differently from a user-executed command: (ex. the result of a consent prompt), should be handled using the authorization level of COLLAR_INTERNALS.. NOTE: COLLAR_INTERNALS should be granted full authority. See GetCollarInternalsMask()

integer GetCollarInternalsMask()
{
    return C_SUPORT|C_COLLAR_INTERNALS|C_OWNER;
}


integer C_ZERO=0;

// - Authorization Calculation -
integer CalcAuthMask(key kID, integer iVerbose)
{
    integer iMask = 0; // If this remains a 0, then that means no access.
    if(kID == g_kWearer)
    {
        iMask += C_WEARER;
    }
    if(llListFindList(g_lOwner, [(string)kID])!=-1)iMask += C_OWNER;
    if(llListFindList(g_lTrust, [(string)kID])!=-1)iMask += C_TRUSTED;
    if(llListFindList(g_lBlock, [(string)kID])!=-1)iMask += C_BLOCKED;
    if(in_range(kID) && g_iPublic && kID!=g_kWearer)iMask += C_PUBLIC;
    if(llSameGroup(kID) && in_range(kID) && kID!=g_kWearer)iMask += C_GROUP;

    if(iVerbose && iMask == 0)
    {
        llMessageLinked(LINK_SET,NOTIFY, "0%NOACCESS%", kID);
    }
    return iMask;
}

string AuthMask2Str(integer iMask)
{
    list lAuth = [];
    if(iMask&C_WEARER)lAuth += "Wearer";
    if(iMask&C_OWNER)lAuth+="Owner";
    if(iMask&C_TRUSTED)lAuth+="Trusted";
    if(iMask&C_BLOCKED)lAuth+="BLOCKED";
    if(iMask&C_GROUP)lAuth+="Group";
    if(iMask&C_PUBLIC)lAuth += "Public";

    return llDumpList2String(lAuth, ", ");
}

// Test order: iMask1>iMask2
integer MaskOutranks(integer iMask1, integer iMask2)
{
    // If the first mask has the owner bit, and the second mask has the owner bit, then false.
    if(iMask1&C_OWNER && !(iMask2&C_OWNER))return TRUE;
    else if(iMask1&C_OWNER && iMask2&C_OWNER)return TRUE;

    if(iMask1&C_TRUSTED && !(iMask2&(C_OWNER|C_TRUSTED)))return TRUE;
    else if(iMask1&C_TRUSTED && iMask2&C_TRUSTED && !(iMask2&(C_OWNER)))return TRUE;

    if(iMask1&C_WEARER && !(iMask2&(C_OWNER|C_TRUSTED|C_GROUP)))return TRUE;
    else if(iMask1 &C_WEARER && iMask2&C_WEARER && !(iMask2&C_OWNER|C_GROUP|C_TRUSTED))return TRUE;

    if(iMask1&C_BLOCKED)return FALSE;
    if(iMask1&C_GROUP && !(iMask2&(C_OWNER|C_TRUSTED)))return TRUE;
    if(iMask1&C_PUBLIC)return FALSE;

    return FALSE;
}


integer REBOOT = -1000;
string UPMENU = "BACK";
string ALL = "ALL";
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script sends responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from settings
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value
integer LM_SETTING_RESET = 2006; // Sent to request a full settings reset. Consent prompt handled by zni_settings




string Auth2Str(integer iAuth){
    if(iAuth == CMD_OWNER)return "Owner";
    else if(iAuth == CMD_TRUSTED)return "Trusted";
    else if(iAuth == CMD_GROUP)return "Group";
    else if(iAuth == CMD_WEARER)return "Wearer";
    else if(iAuth == CMD_EVERYONE)return "Public";
    else if(iAuth == CMD_BLOCKED)return "Blocked";
    else if(iAuth == CMD_NOACCESS)return "No Access";
    else return "Unknown = "+(string)iAuth;
}


Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}
string SLURL(key kID){
    return "secondlife:///app/agent/"+(string)kID+"/about";
}


integer CalcAuth(key kID, integer iVerbose){
    string sID = (string)kID;
    // First check
    if(llGetListLength(g_lOwner) == 0 && kID==g_kWearer)
        return CMD_OWNER;
    else{
        if(llListFindList(g_lBlock,[sID])!=-1)return CMD_BLOCKED;
        if(llListFindList(g_lOwner, [sID])!=-1)return CMD_OWNER;
        if(llListFindList(g_lTrust,[sID])!=-1)return CMD_TRUSTED;
        if(g_kTempOwner == kID) return CMD_TRUSTED;
        if(kID==g_kWearer)return CMD_WEARER;
        if(in_range(kID)){
            if(g_kGroup!=NULL_KEY){
                if(llSameGroup(kID))return CMD_GROUP;
            }

            if(g_iPublic)return CMD_EVERYONE;
        }else{
            if(iVerbose)
                llMessageLinked(LINK_SET, NOTIFY, "0%NOACCESS% because you are out of range", kID);
        }
    }


    return CMD_NOACCESS;
}


list StrideOfList(list src, integer stride, integer start, integer end)
{
    list l = [];
    integer ll = llGetListLength(src);
    if(start < 0)start += ll;
    if(end < 0)end += ll;
    if(end < start) return llList2List(src, start, start);
    while(start <= end)
    {
        l += llList2List(src, start, start);
        start += stride;
    }
    return l;
}

string tf(integer a){
    if(a)return "true";
    return "false";
}

integer ALIVE = -55;
integer READY = -56;
integer STARTUP = -57;

integer SENSORDIALOG = -9003;
integer SAY = 1004;



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

integer LEASH_START_MOVEMENT = 6200;
integer LEASH_END_MOVEMENT = 6201;

integer ANIM_START = 7000;
integer ANIM_STOP = 7001;
integer ANIM_LIST_REQ = 7002;
integer ANIM_LIST_RES = 7003;

integer CMD_PARTICLE = 20000;

string UP_ARROW = "↑";
string DOWN_ARROW = "↓";
integer UPDATER = -99999;