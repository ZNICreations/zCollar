/*
This file is a part of zCollar.
Copyright 2021

: Contributors :

Aria (Tashia Redrose)
    * March 2021         - Created zc_installer_relay

et al.


Licensed under the GPLv2. See LICENSE for full details.
https://github.com/zontreck/zCollar
*/


integer UPDATER_CHANNEL = -7483213;
integer RELAY_CHANNEL = -7483212;
integer RELAY_COM_CHANNEL = -7483211;
integer SECURE; // Dynamic

key g_kCollar;
integer g_iCollarPin;
key g_kInstaller;

key g_kParticleTarget;
integer g_iRainbowCycle;
list l_ParticleColours=[<1,0,0>,<1.0,0.5,0>,<1,1,0>,<0,1,0>,<0,0.25,1>,<0.25,0,1>,<0.5,0,1>,<1,0,0>];
Particles(key kTarget) {
    g_kParticleTarget=kTarget;
    vector a=llList2Vector(l_ParticleColours,g_iRainbowCycle);
    vector b=llList2Vector(l_ParticleColours,g_iRainbowCycle+1);
    g_iRainbowCycle++;
    if(g_iRainbowCycle>6) g_iRainbowCycle=0;
    llParticleSystem([
            PSYS_SRC_PATTERN,PSYS_SRC_PATTERN_EXPLODE,
            PSYS_SRC_BURST_RADIUS,0,
            PSYS_SRC_ANGLE_BEGIN,0.1,
            PSYS_SRC_ANGLE_END,-0.1,
            PSYS_SRC_TARGET_KEY,g_kParticleTarget,
            PSYS_PART_START_COLOR,a,
            PSYS_PART_END_COLOR,b,
            PSYS_PART_START_ALPHA,1,
            PSYS_PART_END_ALPHA,1,
            PSYS_PART_START_GLOW,0,
            PSYS_PART_END_GLOW,0,
            PSYS_PART_BLEND_FUNC_SOURCE,PSYS_PART_BF_SOURCE_ALPHA,
            PSYS_PART_BLEND_FUNC_DEST,PSYS_PART_BF_ONE_MINUS_SOURCE_ALPHA,
            PSYS_PART_START_SCALE,<0.150000,0.150000,0.000000>,
            PSYS_PART_END_SCALE,<0.031000,0.031000,0.000000>,
            PSYS_SRC_MAX_AGE,0,
            PSYS_PART_MAX_AGE,2.9,
            PSYS_SRC_BURST_RATE,0.1,
            PSYS_SRC_BURST_PART_COUNT,5,
            PSYS_SRC_ACCEL,<0.000000,0.000000,0.000000>,
            PSYS_SRC_OMEGA,<0.000000,0.000000,0.000000>,
            PSYS_SRC_BURST_SPEED_MIN,0.1,
            PSYS_SRC_BURST_SPEED_MAX,0.9,
            PSYS_PART_FLAGS,
                0 |
                PSYS_PART_EMISSIVE_MASK |
                PSYS_PART_INTERP_COLOR_MASK |
                PSYS_PART_INTERP_SCALE_MASK |
                PSYS_PART_TARGET_POS_MASK
        ]);
        llSensorRepeat("*&^","6b4092ce-5e5a-ff2e-42e0-3d4c1a069b2f",AGENT,0.1,0.1,0.6);
}
default
{
    state_entry()
    {
        llSetObjectName("zc_installer_relay");
        llSetText("ZNI Update Relay\nv1.0\n\n* Must not be rezzed by itself *", <0,1,1>, 1);

        llListen(UPDATER_CHANNEL, "", "", "");
        llListen(RELAY_CHANNEL, "", "", "");

        llSay(UPDATER_CHANNEL, "AnnounceRelay");
        llSetStatus(STATUS_PHANTOM,TRUE);
        llAllowInventoryDrop(TRUE);
    }

    no_sensor(){
        Particles(g_kParticleTarget);
    }

    on_rez(integer c){
        llSetPrimitiveParams([PRIM_TEMP_ON_REZ,TRUE]);
        llResetScript();
    }

    listen(integer c, string n, key i,string m)
    {
        if(c == RELAY_CHANNEL)
        {
            //llSay(0, "Message to UpdateRelay: "+m);
            list lParam = llParseString2List(m,["|"],[]);
            if(llList2String(lParam,0) == "PrepareRelay")
            {
                g_kInstaller = i;
                integer pin = llRound(llFrand(57438476));
                llRegionSayTo(i, UPDATER_CHANNEL, "ReallyRelayReady");
                llSetPrimitiveParams([PRIM_TEMP_ON_REZ,FALSE]);

                llSetText("ZNI Update Relay\n\n* Preparation in progress *", <1,0,0>,1);
            } else if(llList2String(lParam,0)=="ShimSent")
            {
                g_kCollar = (key)llList2String(lParam,1);
                //g_iCollarPin = (integer)llList2String(lParam,2);

                //llRemoteLoadScriptPin(g_kCollar, "oc_update_shim", g_iCollarPin, TRUE, -999);
                //llSay(0, "We have the update shim. Asking collar for the installation pin!");
                llRegionSayTo(g_kCollar, UPDATER_CHANNEL, "RequestPin|"+llList2String(lParam,2));
            } else if(llList2String(lParam,0)=="reallyready")
            {
                SECURE=(integer)llList2String(lParam,1);
                Particles(g_kCollar);
                llListen(SECURE,"",g_kCollar,"");
                llListen(RELAY_COM_CHANNEL, "", g_kInstaller, "");
                llRemoveInventory("zc_update_shim");
                llRegionSayTo(g_kInstaller, UPDATER_CHANNEL, "reallyready|"+(string)RELAY_COM_CHANNEL);

                llSetText("ZNI Update Relay\n\n* In Progress *",<1,0,0>,1);
            } else if(llList2String(lParam,0) == "wait_prepare")
            {
                SECURE = (integer)llList2String(lParam,1);
                Particles(g_kCollar);
            } else if(llList2String(lParam,0) == "Prepared")
            {
                llRegionSayTo(g_kCollar, SECURE, "PREP_DONE");
            } else if(llList2String(lParam,0)=="Send"){
                while(llGetInventoryType(llList2String(lParam,2))==INVENTORY_NONE){}
                llSleep(2);
                if(llList2String(lParam,1)=="GIVE")llGiveInventory(g_kCollar, llList2String(lParam,2));
                else if(llList2String(lParam,1) == "INSTALL")llRemoteLoadScriptPin(g_kCollar, llList2String(lParam,2), g_iCollarPin, TRUE, 1);
                else if(llList2String(lParam,1) == "INSTALLSTOPPED")llRemoteLoadScriptPin(g_kCollar, llList2String(lParam,2), g_iCollarPin, FALSE, 1);
                //llSay(0, "Instruction "+m);
                llSleep(1);
                llRemoveInventory(llList2String(lParam,2));

            } else if(llList2String(lParam,0) == "pkg_get")
            {
                llRegionSayTo(g_kInstaller, UPDATER_CHANNEL, "pkg_get|"+(string)RELAY_CHANNEL);
            } else if(llList2String(lParam,0)=="pkg_reply")
            {
                llRegionSayTo(g_kCollar, SECURE, m);
            } else if(llList2String(lParam,0) == "pkg_set")
            {
                llRegionSayTo(g_kInstaller, UPDATER_CHANNEL, m);
            }
        } else if(c==UPDATER_CHANNEL){
            //llSay(0, "Message on the update channel: "+m);
            list lParam = llParseString2List(m,["|"],[]);
            if(llList2String(lParam,0)=="ready")
            {
                g_iCollarPin = (integer)llList2String(lParam,1);
                llRemoteLoadScriptPin(g_kCollar, "zc_update_shim", g_iCollarPin, TRUE, -999);
                llRegionSayTo(g_kInstaller, UPDATER_CHANNEL, "shiminstalled");
            }
        } else if(c == RELAY_COM_CHANNEL)
        {
            //llSay(0, "Message on transaction channel: "+m);
            llRegionSayTo(g_kCollar,SECURE,m);
            if(m == "DONE"){
                llSensorRemove();
                llParticleSystem([]);
                llSetPrimitiveParams([PRIM_TEMP_ON_REZ,TRUE, PRIM_TEXT, "ZNI Update Relay\n \n* Finishing Up *", <0,1,0>,1]);
            }
        } else if(c == SECURE)
        {
            //llSay(0, "Message on secure transaction channel: "+m);
            llRegionSayTo(g_kInstaller,RELAY_COM_CHANNEL, m);
            // Shim wont acknowledge a done signal, so this is all we have to do here
        }
    }
}
