<?php
if(!defined("COMMON"))
    require("Common.php");

$DB = get_DB();

$SL = get_SL_Owner();

function make($DB, $q){
    switch($q){
        case 1:
            {
                $DB->query("create table if not exists settings (SLName varchar(255), Token varchar(255), Variable varchar(255), Value varchar(255));");
                $DB->query("alter table settings add constraint unq unique (Token, Variable);");
                break;
            }
            case 2: {
                $DB->query("create database if not exists 'zcollar';");
                break;
            }
    }
}

make($DB, 2);
change_DB($DB, "zcollar");


make($DB, 1);

/* Script Specific Section */
function run($DB, $SL, $r, $args){
    switch($r){
        case 1: {
            // Get number of settings
            $res = $DB->query("select * from settings where SLName=\"".$SL."\";");
            if(!$res)die("Collar_Settings;;NB;;0");
            die("Collar_Settings;;NB;;".$res->num_rows);
            break;
        }
        case 2:{
            $res = $DB->query("select * from settings where SLName=\"".$SL."\" and Token=\"".$args["token"]."\" and Variable=\"".$args["var"]."\";");
            
            if(!$res)
                die("Collar_Settings;;GET;;".$args["token"].";".$args["var"]);
            $assoc = $res->fetch_assoc();
            
            die("Collar_Settings;;GET;;".$args["token"].";".$args["var"].";".$assoc["Value"]);
            
            break;
        }
        case 3:{
            $DB->query("replace into settings (SLName, Token, Variable, Value) values (\"".$SL."\", \"".$args["token"]."\", \"".$args["var"]."\", \"".$args["val"]."\");");
            die("Collar_Settings;;GET;;".$args["token"].";".$args["var"].";".$args["val"]);
            break;
        }
        case 4:{
            $res=$DB->query("select * from settings where SLName=\"".$SL."\" limit ".$args["max"]. " offset ".$args['min'].";");
            $results = array();
            while($row = $res->fetch_assoc()){
                // 
                array_push($results, $row['Token'].";".$row['Variable'].";".$row['Value']);
            }

            die("Collar_Settings;;RANGE_GET;;".$args["min"].";".$args["max"].";;".implode("~", $results));
            break;
        }
        case 5:{
            $DB->query("delete from settings where SLName=\"".$SL."\" and Token=\"".$args['token']."\" and Variable=\"".$args['var']."\";");
            die("Collar_Settings;;DELETE;;".$args['token'].";".$args['var']);
            break;
        }
        case 6:{
            $DB->query("delete from settings where SLName=\"".$SL."\";");
            die("Collar_Settings;;RESET");
            break;
        }
        case 7:{
            $res = $DB->query("select * from settings where SLName=\"".$SL."\" and Token=\"".$args['token']."\" and Variable=\"".$args['var']."\";");
            if(!$res)die("Collar_Settings;;CHECK;;0");
            if($res->num_rows == 0)die("Collar_Settings;;CHECK;;0");
            die("Collar_Settings;;CHECK;;1");
            break;
        }
        case 8:{
            $res = $DB->query("select * from settings where SLName=\"".$SL."\";");
            $results = array();
            if(!$res)die("Collar_Settings;;TOKENS;;");
            while($row = $res->fetch_assoc()){
                array_push($results, $row['Token']);
            }

            die("Collar_Settings;;TOKENS;;".implode("~", $results));
            break;
        }
        case 9:{
            $res = $DB->query("select * from settings where SLName=\"".$SL."\" and Token=\"".$args['token']."\";");
            $results = array();
            if(!$res)die("Collar_Settings;;VARIABLES;;".$args['token'].";;");
            while($row = $res->fetch_assoc()){
                array_push($results, $row['Variable']);
            }
            die("Collar_Settings;;VARIABLES;;".$args['token'].";;".implode("~", $results));
            break;
        }
    }
}
$tok = $_REQUEST['token'];
$var = $_REQUEST['var'];
$val = $_REQUEST['val'];
$type = $_REQUEST['type'];
$arg = array();
$arg["token"] = $tok;
$arg["var"] = $var;
$arg["val"] = $val;
$arg["min"] = $_REQUEST['minimum'];
$arg["max"] = $_REQUEST['maximum'];


if($type == "LIST")run($DB, $SL, 1, $arg);
else if($type == "GET")run($DB, $SL, 2, $arg);
else if($type == "PUT")run($DB, $SL, 3, $arg);
else if($type == "ALL")run($DB, $SL, 4, $arg);
else if($type == "DELETE") run($DB, $SL, 5, $arg);
else if($type == "RESET")run($DB, $SL, 6, $arg);
else if($type == "CHECK")run($DB, $SL, 7, $arg);
else if($type == "TOKENS")run($DB, $SL, 8, $arg);
else if($type == "VARIABLES") run ($DB, $SL, 9, $arg);


?>