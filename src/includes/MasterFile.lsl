 
string COLLAR_VERSION = "10.0.0002"; // Provide enough room

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer TIMEOUT_READY = 30497;
integer TIMEOUT_REGISTER = 30498;
integer TIMEOUT_FIRED = 30499;

integer bool(integer a){
    if(a)return TRUE;
    else return FALSE;
}
list g_lCheckboxes=["□","▣"];
string Checkbox(integer iValue, string sLabel) {
    return llList2String(g_lCheckboxes, bool(iValue))+" "+sLabel;
}

integer QUERY_FOLDER_LOCKS = -9100;
integer REPLY_FOLDER_LOCKS = -9101;
integer SET_FOLDER_LOCK = -9102;
integer CLEAR_FOLDER_LOCKS = -9103;

integer SUMMON_PARTICLES = -58931; // Used only for cuffs to summon particles from one NAMED leash point to another NAMED anchor point
// SUMMON_PARTICLES should follow this message format: <From Name>|<To Name>|<Age>|<Gravity>
integer QUERY_POINT_KEY = -58932;
// This query is automatically triggered and the REPLY signal immediately spawns in particles via the SetParticles function
// Replies to this query are posted on the REPLY_POINT_KEY
// Message format for QUERY is: <Name>       | kID identifier
integer REPLY_POINT_KEY = -58933;
// Reply format: <kID identifier>       |kID  <Key>
integer CLEAR_ALL_CHAINS = -58934;
integer STOP_CUFF_POSE = -58935; // <-- stops all active animations originating from this cuff
integer DESUMMON_PARTICLES = -58936; // Message only includes the From point name


integer NOTIFY = 1002;
integer NOTIFY_OWNERS=1003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer DO_RLV_REFRESH = 26001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used RLV viewer version upon receiving this message..
integer RLVA_VERSION = 6004; //RLV Plugins can recieve the used RLVa viewer version upon receiving this message..

integer RLV_OFF = 6100;
integer RLV_ON = 6101;
integer RLV_QUERY = 6102;
integer RLV_RESPONSE = 6103;


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
integer C_CAPTOR = 256;

integer LINK_CMD_RESTRICTIONS = -2576;
integer LINK_CMD_RESTDATA = -2577;
integer GetCollarInternalsMask()
{
    return C_SUPORT|C_COLLAR_INTERNALS|C_OWNER;
}

integer g_iLimitRange=TRUE;
integer in_range(key kID){
    if(!g_iLimitRange)return TRUE;
    if(kID == g_kWearer)return TRUE;
    else{
        vector pos = llList2Vector(llGetObjectDetails(kID, [OBJECT_POS]),0);
        if(llVecDist(llGetPos(),pos) <=20.0)return TRUE;
        else return FALSE;
    }
}

key g_kCaptor;
integer C_ZERO=0;

integer g_iSupportLockout=FALSE;
list g_lSupportReps = ["5556d037-3990-4204-a949-73e56cd3cb06", "7cbd7a16-83fa-42bd-9f85-79005fe78430"];
key g_kSupport = NULL_KEY;
// - Authorization Calculation -
integer CalcAuthMask(key kID, integer iVerbose)
{
    integer iMask = 0; // If this remains a 0, then that means no access.
    if(kID == g_kWearer)
    {
        iMask += C_WEARER;
    }
    if(llListFindList(g_lOwner, [(string)kID])!=-1 || (g_kSupport == kID && g_kSupport!=NULL))iMask += C_OWNER;
    if(llListFindList(g_lTrust, [(string)kID])!=-1)iMask += C_TRUSTED;
    if(llListFindList(g_lBlock, [(string)kID])!=-1)iMask += C_BLOCKED;
    if(in_range(kID) && g_iPublic && kID!=g_kWearer)iMask += C_PUBLIC;
    if(llSameGroup(kID) && in_range(kID) && kID!=g_kWearer && (g_kGroup != "" && g_kGroup != NULL))iMask += C_GROUP;

    if(g_kCaptor != "") iMask += C_CAPTOR;
    if(iMask&C_CAPTOR && !(iMask&C_TRUSTED))iMask += C_TRUSTED;

    if(kID == llGetKey()) iMask += C_COLLAR_INTERNALS;
    if(llListFindList(g_lSupportReps, [(string)kID])!=-1){
        if(g_iSupportLockout && (iMask&C_WEARER)){}else
            iMask += C_SUPPORT;
    }

    if(iVerbose && iMask == 0)
    {
        llMessageLinked(LINK_SET,NOTIFY, "0%NOACCESS%", kID);
    }

    if(iMask & C_WEARER){
        if(g_lOwner == [] && g_lTrust==[] && llListFindList(g_lBlock, [(string)g_kWearer])==-1)iMask+=C_OWNER;
    }
    return iMask;
}

string AuthMask2Str(integer iMask)
{
    list lAuth = [];
    if(iMask&C_SUPPORT)lAuth += "ZNI Support";
    if(iMask&C_COLLAR_INTERNALS)lAuth += "Collar Internals";
    if(iMask&C_WEARER)lAuth += "Wearer";
    if(iMask&C_OWNER)lAuth+="Owner";
    if(iMask&C_TRUSTED)lAuth+="Trusted";
    if(iMask&C_BLOCKED)lAuth+="BLOCKED";
    if(iMask&C_GROUP)lAuth+="Group";
    if(iMask&C_PUBLIC)lAuth += "Public";
    if(iMask&C_CAPTOR)lAuth += "Captor";

    if(iMask == 0) lAuth = ["No Access"];

    return llDumpList2String(lAuth, ", ");
}

// Test order: iMask1>iMask2
integer MaskOutranks(integer iMask1, integer iMask2)
{
    if(iMask1 & C_COLLAR_INTERNALS) return TRUE;
    
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
integer SENSORDIALOG = -9003;
integer DIALOG_EXPIRE_ALL = -9004;
integer DIALOG_RENDER = -9013;
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


integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

integer LOADPIN = -1904;
integer ANIM_LIST_REQ = 7002;
integer ANIM_LIST_RES = 7003;

integer CMD_PARTICLE = 20000;

string UP_ARROW = "↑";
string DOWN_ARROW = "↓";
integer UPDATER = -99999;
list g_lMenuIDs;
integer g_iMenuStride;

string getperms(string inventory)
{
    integer perm = llGetInventoryPermMask(inventory,MASK_NEXT);
    integer fullPerms = PERM_COPY | PERM_MODIFY | PERM_TRANSFER;
    integer copyModPerms = PERM_COPY | PERM_MODIFY;
    integer copyTransPerms = PERM_COPY | PERM_TRANSFER;
    integer modTransPerms = PERM_MODIFY | PERM_TRANSFER;
    string output = "";
    if ((perm & fullPerms) == fullPerms)
        output += "full";
    else if ((perm & copyModPerms) == copyModPerms)
        output += "copy & modify";
    else if ((perm & copyTransPerms) == copyTransPerms)
        output += "copy & transfer";
    else if ((perm & modTransPerms) == modTransPerms)
        output += "modify & transfer";
    else if ((perm & PERM_COPY) == PERM_COPY)
        output += "copy";
    else if ((perm & PERM_TRANSFER) == PERM_TRANSFER)
        output += "transfer";
    else
        output += "none";
    return  output;
}
