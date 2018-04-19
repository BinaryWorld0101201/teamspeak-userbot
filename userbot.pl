#!/usr/bin/perl
#####################################################################
# Copyright notice			
#																	
# Written by Marcel Spark <http://mzhost.de/>						
# (C) 2013 maze 													
#																	
# This script is distributed in the hope that it will be useful,	
# but WITHOUT ANY WARRANTY; without even the implied warranty of	
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.				
#																	
# This copyright notice MUST APPEAR in all copies of the script!	
#####################################################################
use Net::Telnet; # use cpan telnet
use Fcntl qw(:flock); 

# CONFIG
my $debugvar="0"; #debuggen: 1=on 0=off
%ARGS = (
			"queryname"=>"testuser",
			"querypw"=>"password",
			"nickname"=>"BotName",
			"serverid"=>"1",
			"usechannelid"=>"1",
			"befehle_list"=>"!Befehle:ID",
			"admin_list"=>"Liste der voll Berechtigten",
			"limitservergroup"=>"0",
			"disabledel"=>"0",
			"Auto_channelid" =>"0",
			"Auto_channelorder" =>"1",
			"server_ip" => "127.0.0.1",
			"query_port" => "10011"
		);

# / CONFIG

my $LOCFH;
&parse_args;
&debugini();
&parse_ini($inifile);
if(&prg_running($inifile) ){
	print "\nProgramm wird schon ausgefuehrt!\n";
	exit(0);
}

my $ownid = &qlogin ("Hallo");

mainloop ();
#hier kommt keiner mehr hin
exit (0);

sub mainloop {
	my $invokerid="empty"; 
	my $invokeruid="empty"; 
	my $msg="empty"; #nachricht vom user
	my $akt_befehl = ""; #hilfvariablen
	my $dbid = ""; #database id
	my @groupids = "";
	my $line; #user eingabe
	

	
	while (TRUE) { # loop forever...
		
next_line:
		$line = $query->getline(Timeout => 250); # read / wait for incoming message lines (private and channel)
		$line =~ s/[\r\n]//g;	
		if ($line eq ""){
			#user ist eingeschlafen....
			#debugout("timeout erreicht");	
			$ownid=qlogin (""); 
			goto next_line;
		}
		if ($ARGS{Auto_channelid} ne "0"){
			#debugout("Line:".$line);
			if (&CheckAutoMove($line)){
				debugout("Moved...");
				goto next_line;
			}
		}
		if ( !($line =~ / msg=!/)) {
			#performance....
			debugout("Uebersrungen:".$line);
			goto next_line;
		}
	
		debugout("GetLine(): $line");

		my @line_values = split(" ",$line); # << das ist reingekommen
		foreach my $e (@line_values) 
		{

			if ($e =~ /invokeruid?/) #prüft nach "invokerid"
			{
				$e =~s/invokeruid=//; #filtert die genaue invokerid=""
				$invokeruid=$e;
			}
			if ($e =~ /invokerid?/) #prüft nach "invokerid"
			{
				$e =~s/invokerid=//; #filtert die genau invokerid=""
				$invokerid=$e;
			}
			if ($e =~ /msg=?/) #
			{
				$e =~s/msg=//; #
				$msg=$e;
				$akt_befehl = "";
				foreach my $key ( keys %Befehle )  {
					if ($msg eq $key){
						$akt_befehl=$key;
						last;
					}
				}
			}
		}
		debugout ("InvokerID:$invokerid InvokerIUD:$invokeruid msg:$msg");
		#Abfrage der AdminList
		if ( index($ARGS{admin_list},$invokeruid) >= 0 )
		{
			
			#Sonderbefehle für admin
			if ( $msg eq "!quit" )
			{
				SendText("Bye Bye...");	
				$query->print("logout");				
				debugout ("!QUIT");
				&prgexit (0);
			}	
			elsif ( $msg eq "!reload" )
			{
				SendText("Neustart...");			
				debugout ("!RELOAD");
				&parse_ini($inifile);
				$ownid = &qlogin ("Hallo");
				goto next_line;
			}
			elsif ( $msg =~ /!movebot=(.+)/ )
			{
				SendText("Wird gemoved...");			
				debugout ("clientmove clid=$ownid cid=$1");
				$query->print("clientmove clid=$ownid cid=$1"); # move own id to channel 
				debugout ("Move Bot: ".$query->getline ());
				goto next_line;
			}
			elsif ( $msg =~ /!debug/ )
			{
				if($debugvar eq "0" ){
					SendText("Debug wird enabled...");
					$debugvar="1";
					&debugini();
				}
				else{
					SendText("Debug wird disabled...");
					$debugvar="0";
				}
				goto next_line;
			}	
				
			elsif ( $msg =~ /!movetemp=(.+)/ )
			{
				#SendText("Temp Channels moven...");			
				SendText(&MoveTempChannels($1)." Channels wurden zur id $1 verschoben");
				goto next_line;
			}	
			
		}
		###Echo vom Bot wird nicht ausgewertet
		###ist eigentlich überflüssig
		if($invokerid eq $ownid) {
			debugout ("Zeile wird nicht ausgewertet ($invokerid) $line");
			goto next_line;
		}
		###
		if ( $msg eq "!help" )
		{
			my $HelpText = "Befehle:\\n";
			
			foreach my $key ( sort keys %Befehle )  {
				$HelpText .= $key."\\n";
			}			
			if ( index($ARGS{admin_list},$invokeruid) >= 0 ) {
				$HelpText .= "!debug\\n!movebot=to_channelid\\n!movetemp=to_channelid\\n!reload\\n!quit\\n";
			}
			SendText($HelpText);
		}	
		elsif ( $akt_befehl ne "" )
		{
			debugout ("Befehl gefunden: $akt_befehl"); 
			if ($akt_befehl =~ /-del/ && $invokerid ne "empty")
			{
				@RetVal = dbgetinfo ($invokerid);
				$dbid = $RetVal[0];
				groupdel($Befehle{$akt_befehl},$dbid);
			}
			elsif ($Befehle{$akt_befehl} ne "" && $invokerid ne "empty")
			{				
				@RetVal = dbgetinfo ($invokerid);
				$dbid =$RetVal[0]; 
				if ($ARGS{limitservergroup} eq "1" ){
					@groupids =split(",",$RetVal[1]);
					# a > hier will er hin:  $Befehle{$akt_befehl} 7
					# b > hier ist er drin:  @groupids 	6,9
					# c > hier kann er hin:  %Befehle 7,9
					foreach my $key ( keys %Befehle )  {
						if ( !($key =~ /-del/)){
							foreach my $y(@groupids) {
								if ($y eq $Befehle{$key} && $y ne $Befehle{$akt_befehl}) {
									groupdel($y,$dbid);
									#debugout("Schon in Gruppe: $y ($key)");
								}				
							}
						}
					}
				}
				groupadd($Befehle{$akt_befehl},$dbid);
	
			}
		}
	}
}
sub ChannelsOrderList{
	my $to_pid = shift;
	my $in_arr =shift;
	my @channels;
	my $sic = 0;
	my $ergebniss ="";
	my $cid="";
	my $order=0;
	my $pid="";

	$query->print('channellist'); 
	while ($sic < 4) { 
		$ergebniss = $query->getline();
		$ergebniss =~ s/[\t\r\n]//gi;
		$sic = $sic + 1; 
		if ($ergebniss =~ /^cid=/ ) {
				last;
		}
	}
	@channels = split ('\|',$ergebniss);

	if (@channels < 1 ) {
		SendText("Fehler:Channels konnten nicht gelistet werden.");
		return 0;
	}
	
	#Channellist liefert sortierte Folge!
	foreach my $cha (@channels) {
		$cha =~ /cid=(.+?) /;
		$cid = $1;
		$cha =~ /pid=(.+?) /;
		$pid = $1;
		if($pid eq $to_pid) {
			#Die Letzte Cid ist die Cid an der angefügt wird
			$order = $cid;
		}
		else {
			#alle channel die noch keine pid haben ins array pushen
			push (@{$in_arr},$cha);
		}
		
	}
	return $order;
	
}
sub CheckAutoMove{
	my $line =shift;
	my $cid="";
	my $sic = 0;
	my $ergebniss ="";
	my @Temp;
	my $order =0;
	
	if ($line =~ /notifychannelcreated /){
		$line =~ /cid=(.+?) /;
		$cid = $1;
		debugout("AutoMove Channel: $cid");
		$query->print('channelinfo cid='.$cid); 
		while ($sic < 4) { 
			$ergebniss = $query->getline();
			$ergebniss =~ s/[\t\r\n]//gi;
			$sic = $sic + 1; 
			#debugout("Move $sic: $ergebniss");
			if ($ergebniss =~ /^pid=/ ) {
				last;
			}
		}
		if ($ergebniss =~ /channel_flag_temporary=1|channel_flag_permanent=0 channel_flag_semi_permanent=0/){ # channel_flag_default=0/){
			#temp channel
			if ( $ARGS{Auto_channelorder} eq "1" ){
				$order=&ChannelsOrderList($ARGS{Auto_channelid},\@Temp);		
			}
			debugout('channelmove cid='.$cid.' cpid='.$ARGS{Auto_channelid}.' order='.$order);
			$query->print('channelmove cid='.$cid.' cpid='.$ARGS{Auto_channelid}.' order='.$order);
			$sic=0;
			while ($sic < 3) { 
				$ergebniss = $query->getline();
				$ergebniss =~ s/[\t\r\n]//gi;
				$sic = $sic + 1; 
				if ($ergebniss =~ /error id=0 msg=ok/ ) {
					return 1;
				}
				elsif ($ergebniss =~ /error id=/ ) {
					debugout("AutoMove error: $ergebniss");
					return 0;
				}

			}
		}

	}
	return 0;
}
sub MoveTempChannels{
	my $to_cid=shift;
	my @channels;
	my $order=0;
	my $sic = 0;
	my $move =0;
	my $count =0;
	my $ergebniss ="";
	my $cid="";
	
	debugout("Move TempChannels: $to_cid");
	$order = &ChannelsOrderList($to_cid,\@channels);
	# order enthaelt die letzte cid im pid
	foreach my $cha (@channels) {
		$sic = 0;
		$cha =~ /cid=(.+?) /;
		$cid = $1;
		$query->print('channelinfo cid='.$cid); 
		debugout('channelinfo cid='.$cid);
		while ($sic < 4) { 
			$ergebniss = $query->getline();
			$ergebniss =~ s/[\t\r\n]//gi;
			$sic = $sic + 1; 
			if ($ergebniss =~ /^pid=/ ) {
				last;
			}
		}
		$sic=0;
		debugout('channelinfo result:'.$ergebniss);
		if ($ergebniss =~ /channel_flag_temporary=1|channel_flag_permanent=0 channel_flag_semi_permanent=0/){ # channel_flag_default=0/){
			#temp channel
			$count = $count+1;
			if ( $ARGS{Auto_channelorder} ne "1" ){
				$order=0;
			}
			$query->print('channelmove cid='.$cid.' cpid='.$to_cid.' order='.$order);
			debugout('channelmove cid='.$cid.' cpid='.$to_cid.' order='.$order);
			$order = $cid;
			while ($sic < 4) { 
				$ergebniss = $query->getline();
				$ergebniss =~ s/[\t\r\n]//gi;
				$sic = $sic + 1; 
				if ($ergebniss =~ /error id=0/ ) {
					$move = $move+1;
					last;
				}
			}
			debugout('channelmove result:'.$ergebniss);
		}	
	}
	return $move." von ".$count;
}
sub getservergroupname{
	my $grpid = shift;
	my $ergebniss ="";
	my @Groups;
	my $id;
	my $name;
	my $sic = 0;

	$query->print('servergrouplist'); # give the svgrp
	while ($sic < 4) { # loop forever...
		$ergebniss = $query->getline();
		$ergebniss =~ s/[\t\r\n]//gi;
		$sic = $sic + 1; 
		if ($ergebniss =~ /^sgid=/ ) {
			last;
		}
	}
	
	@Groups = split(/\|/,$ergebniss);
	foreach my $x (@Groups) {
		$x =~ /sgid=(.+) name=(.+) type=/;
		$id = $1;
		$name  = $2;
		$name =~ s/\\s/ /g;
		if($grpid eq $id) {
			#debugout("Gruppe gefunden: $id $name");
			return ($name);
		}
	}
	return ("");
}
sub groupadd{
	my $grpid = shift;
	my $dbid = shift;
	my $ergebniss ="";
	my $grpname;
	
	debugout('Befehl:servergroupaddclient sgid='.$grpid.' cldbid='.$dbid);
	$grpname=&getservergroupname($grpid);
	$query->print('servergroupaddclient sgid='.$grpid.' cldbid='.$dbid); # give the svgrp	
	$query->getline(); # skip line
	$ergebniss = $query->getline(Timeout => undef);
	$ergebniss =~ s/[\r\n]//g;
	debugout ("ADDERGEBNISS: $ergebniss");
	if ($ergebniss =~ /msg=ok/)
	{
		SendText("Willkommen in der Gruppe: $grpname"); # $servergroup_name");
	}
	elsif ($ergebniss =~ /msg=duplicate?/)
	{	
		SendText ("Du bist schon in der Gruppe: $grpname");
	}
	else 
	{
		SendText ("Hat leider nicht funktioniert, wende dich an einen Admin");
	}
}
sub groupdel{
	my $grpid = shift;
	my $dbid = shift;
	my $ergebniss ="";
	my $grpname;
	
	debugout('Befehl:servergroupdelclient sgid='.$grpid.' cldbid='.$dbid);
	$grpname=&getservergroupname($grpid);

	$query->print('servergroupdelclient sgid='.$grpid.' cldbid='.$dbid); # give the svgrp	
	$query->getline(); # skip line
	$ergebniss = $query->getline(Timeout => undef); 
	$ergebniss =~ s/[\r\n]//g;
	debugout("DELERGEBNISS: $ergebniss");
	if ($ergebniss =~ /msg=ok/)
	{
		SendText("Du hast die Gruppe $grpname verlassen!"); 
	}
	elsif ($ergebniss =~ /msg=empty?/)
	{	
		SendText ("Du bist nicht in der Gruppe: $grpname");
	}
	else 
	{
		SendText ("Hat leider nicht funktioniert, wende dich an einen Admin");
	}
}
sub debugini {
	if ($debugvar eq "1"){
		open(DEBUGFLI, ">./debug.txt") || die "Fehler aufgetreten: $!";
		print DEBUGFLI "[".&GetZeit."]:[debug erstellt]\n";
		close (DEBUGFLI);}
}
sub debugout {
	 my $Inhalt = shift;
	 if ($debugvar eq "1"){
	 open(DEBUGFLI, ">>./debug.txt") || die "Fehler aufgetreten: $!";
	 print DEBUGFLI  "[".&GetZeit."]:[".$Inhalt."]\n";
	 close (DEBUGFLI);}
 }
sub dbgetinfo {
	 my $invid = shift;
	 my $info = "";
	 my $temp;
	 my @RetVal =("0","0");
	 $query->print("clientinfo clid=$invid"); # sucht nach der DBID (mithilfer der invid)
	 $info = $query->getline(); # 
	 $temp = $info;
	 #debugout ("getinfo:" .$info);

	 $info =~ /(client_database_id)=(\d*?) /; 
	 $RetVal[0] = $2;

	 $temp =~ /(client_servergroups)=(.+?) /; 
	 $RetVal[1] = $2;

	 debugout ("dbgetinfo groupid: $RetVal[1] dbid: $RetVal[0]"); #gibt die dbid aus
	 return (@RetVal);
 }
sub SendText {
	my $out =shift;
	
	$out =~ s/ /\\s/gi;
	$query->print("sendtextmessage targetmode=2 msg=$out");	
}
sub CheckResult{
	my $line =shift;
	my $check = shift;
	my $msg=shift;
	$line =~ s/\r\n\t//gi;
	
	if( $line =~ /$check/) {
		return;
	}
	print "\n".$msg."\n";
	&prgexit(0);
}
sub qlogin{
	my $msg = shift;
	my $line;
	my $tmp=$inifile;
	$tmp =~ s/.ini//;
	
	$query = new Net::Telnet (Timeout => undef); 
	$query->open(Host => $ARGS{server_ip}, # host-ip and port for th telnet connection
				 Port => $ARGS{query_port});
	$query->errmode( sub { sleep 0.1 } );
	sleep 0.5;
	CheckResult($query->getline(),"TS3","Verbindung zum Sever fehlgeschlagen!!"); # TS3 
	$query->getline();
	$query->print("login $ARGS{queryname} $ARGS{querypw}"); #login
	CheckResult($query->getline(),"error id=.*? msg=ok","Login fehlgeschlagen!!");
	$query->print("use $ARGS{serverid}"); 
	CheckResult($query->getline(),"error id=.*? msg=ok","Use auf ServerID '$ARGS{serverid}' fehlgeschlagen!!");
	$query->print("clientupdate client_nickname=$ARGS{nickname}");  
	CheckResult($query->getline(),"error id=.*? msg=ok","Nickname '$ARGS{nickname}' konnte nicht gesetzt werden!!");
	$query->print("whoami"); 
	$line= $query->getline(); 
	CheckResult($query->getline(),"error id=.*? msg=ok","Whoami fehlgeschlagen!!");
	$line =~ s/[\r\n\t]//gi;
	$line =~ s/= /# /gi;
	my %hash = split /[=\s]/, $line;
	$query->print("clientmove clid=$hash{client_id} cid=$ARGS{usechannelid}"); # move own id to channel 
	CheckResult($query->getline(),"error id=.*? msg=(ok|alre)","Move fehlgeschlagen!!");
	if ($msg ne "") {
		$query->print("sendtextmessage targetmode=2 msg=$msg");  
		$query->getline(); # skip response line
	}
	$query->print("servernotifyregister event=textchannel");  
	CheckResult($query->getline(),"error id=.*? msg=ok","NotifyRegister Textchannel fehlgeschlagen!!");
	if ($ARGS{Auto_channelid} ne "0"){
		$query->print("servernotifyregister id=0 event=channel");  
		CheckResult($query->getline(),"error id=.*? msg=ok","NotifyRegister Channel fehlgeschlagen!!");	
	}
	open (my $pid ,'>./'.$tmp.".pid");
	print $pid $$;
	close($pid);
	return $hash{client_id};
}
sub parse_ini {
	my $in_file = shift;
	my $Line;
	my @nBefehle;
	my @Paare;
	my $x;

	%Befehle = ();

	open(HANDLE, "<".$in_file) or &create_ini($in_file);
	debugout("Lese Ini:");
	while (<HANDLE>)
	{
		$Line= $_ ;
		$Line =~ s/\s//gi;   #\t\n etc. raus
		$Line =~ s/#.+//gi;  #alles nach # raus
		$Line =~ s/\\s/ /gi; #\s durch leerzeichen ersetzen
		
		if($Line ne "")
		{
			$Line =~ /(.+?)=(.+)/gi;
			foreach my $key (keys %ARGS){
				if ($1 eq "befehle_list" && $key eq $1){
					$ARGS{$1} = $2;
					%Befehle = split /[:;]/,$2;
				}
				elsif ($1 eq $key) {
					$ARGS{$1} = $2;
				}
			}
		}
	}
	close (HANDLE);
	if($ARGS{disabledel} eq "0"){
		foreach my $key ( keys %Befehle )  {
			$Befehle{$key."-del"}=$Befehle{$key};
		}
	}
	if ($debugvar eq "1"){
		debugout("Konfig:");
		foreach my $key ( keys %ARGS )  {
			if($key ne "querypw"){
				debugout($key."=".$ARGS{$key});}
		}
		debugout("Befehle:");
		foreach my $key ( keys %Befehle )  {
			debugout($key." ID: ".$Befehle{$key});
		}
	}
	return 0;
}
sub parse_args {
	my $procname = $0;
	my $tmp="";
	
	if($ARGV[0] ne "status" && @ARGV ne 2 ){
		print "\nFalsche Anzahl an Parameter!\nAufruf: $procname [start|stop|create|status] inifile \n\n";
		exit (0);
	}
	$procname =~ s/.\///;
	$inifile = $ARGV[1];
	$inifile =~ s/.ini//gi;
	$inifile =~ s/.+\///;
	$inifile .= ".ini";

	if ( $ARGV[0] =~ /start|create|stop|status/ ) {
		if($ARGV[0] eq "create"){
			&create_ini($inifile);
			exit(0);
		}
		if($ARGV[0] eq "stop"){
			&prg_stop($inifile);
		}
		if($ARGV[0] eq "status"){		
			open(FILE, "ps -ef|");
			while (<FILE>)
			{
				$tmp=$_;
				if( $tmp =~ /$procname start/ ){
					$tmp =~ s/\/usr\/bin\/perl .\/$procname start //gi;
					print $tmp;
				}
			};
			close(FILE);	
			exit (0);
		}
	}
	else { 
		print "\nFalscher Parameter!\nAufruf: $procname [start|stop|create|status] inifile \n\n";
		exit (0);
	}

}
sub create_ini{
	my $in_file = shift;
	if ($ARGV [0] ne "create") {
		print "\nDatei: $in_file nicht vorhanden \n \n";
		exit (0);
	}
	debugout("Ini wird erstellt");

	open(HANDLE, ">".$in_file) or die;
	while ( <DATA> ) {
		#chomp if $. == 1;
		print HANDLE;
		#print "\n" if eof;
	}

	#print HANDLE $initext;	
	
	#foreach my $key ( keys %ARGS )  {
	#	print HANDLE $key."=".$ARGS{$key}."\n";
    #

	close (HANDLE);
	print "\n\nIni Datei erstellt, bitte Werte bearbeiten!!\n\n";
	debugout("Ini erstellt");
	exit (0);
}
sub prg_running {
    my $f = shift;
	sysopen( $LOCFH, $f, O_RDONLY );
	#open(fh, '>>'.$f);
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm 2; 
        flock( $LOCFH, LOCK_EX ); # attempt to get an exclusive lock
        alarm 0; # cancel any timeouts if we successfully got a lock
    };
    # returns true if the flock call timed out, false otherwise
    return $@ eq "alarm\n"
}
sub prg_release {
   # release the lock and close the filehandle
    flock( $LOCFH, LOCK_UN );
    close( $LOCFH );
} 
sub prg_stop{
	my $f =shift;
	my $kpid="";

	$f =~ s/.ini//;
	open(my $PID, '<./'.$f.".pid") || die "Pid-Datei nicht gefunden!";
	my $geleseneZeichen = read($PID, $kpid, 26);
	if($geleseneZeichen >0 ){
		$kpid =~ s/\s//gi;
		system ("kill $kpid"); 
		unlink ('./'.$f.".pid");
	}
	exit (0);

}
sub prgexit{
	my $code =shift;
	my $tmp=$inifile;
	$tmp =~ s/.ini//;
	&prg_release($inifile);
	unlink ('./'.$tmp.".pid");
	
	exit ( code);
}
sub GetZeit {
	my $Datum;
    my $Zeit;
	my ($sekunde,$minute,$stunde,$tag,$monat,$jahr,$wtag,$ytag,$isdst) = localtime(time);
	$monat++;
	$jahr +=1900;

	if ($stunde < 10) 	{$stunde='0'.$stunde;}
	if ($minute < 10) 	{$minute='0'.$minute;}
	if ($sekunde < 10)	{$sekunde='0'.$sekunde;}
	$Zeit = "$stunde:$minute:$sekunde";

	if ($tag < 10) 	{$tag='0'.$tag;}
	if ($monat < 10) 	{$monat ='0'.$monat;}
	$Datum ="$tag.$monat.$jahr";

	return ("$Datum $Zeit");
}
__DATA__
#Empfohlen wird, erst die README Datei zu lesen!!!

#Wenn die parameter nicht genutzt werden benutzt der userbot 127.0.0.1 und den query Port 10011. (Die # entfernen um die Parameter zu nutzen!)
#server_ip=
#query_port=

#Name des Query Benutzers (z.B serveradmin) und das Passwort
queryname=serveradmin
querypw=abcdefgh

#Diesen Namen benutzt der Bot
nickname=Userbot

#id des Virtuellen Servers auf dem der Bot laufen soll.
serverid=1

#In dieser Channel id wird sich der Bot einloggen. Nur hier sind alle Befehle ausführbar
usechannelid=1

#Anwendung der Befehle stehen in der README. Befehle müssen mit einem ! anfangen. 
#Die Zahl nach dem : gibt die zu verwendende id der Servergruppe an. 
#Die Befehle müssen mit einem ; getrennt werden.
befehle_list=!befehle:6;!befehle2:9

#Die Liste der eindeutigen Identitäten, die die Adminbefehle ausführen dürfen. Siehe README
admin_list=admin1;admin2;etc

#Verhindert, dass ein User in zwei der oben angegeben Gruppen gleichzeitig sein kann. 
#Die bereits vorhandene wird automatisch entfernt. '0' = off '1' = on
limitservergroup=0

#Verhindert den []-del befehl. Der User kann nicht mehr aus der Gruppe austreten. '0' = off '1' = on 
disabledel=0

# In die angegebene Channel Id werden alle Temporären Channel automatisch nach Erstellung gemoved.
# Der Wert '0' stellt die Funktion aus. Der neuste Channel ist automatisch der oberste,
# wenn in 'Auto_channelorder' der Wert '0' steht
Auto_channelid=0

#Dieser Wert schaltet eine Sortierung ein. Dabei wird der neu erstellte - temporäre- Channel an unterster Stelle platziert.  '0' = off
Auto_channelorder=0"

__END__