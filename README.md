# Userbot
Quick and dirty multi-function userbot for TeamSpeak3 

---------

# Installation
```
git clone https://github.com/MzHost/teamspeak-userbot
```
**Dependencies**:
Net Telnet 3: 
Debian 7/8:
```
  apt-get install libnet-telnet-perl
```
Manual Download http://search.cpan.org/CPAN/authors/id/J/JR/JROGERS/Net-Telnet-3.04.tar.gz

# Mögliche Parameter:
```
./userbot.pl {start|stop|create|status} inifile `
``` 
*  `./userbot.pl create [.ini Name]` durch diesen Befehl wird eine ini datei erstellt.
   /home/teamspeak/userbot/userbot.pl create userbot 

* `./userbot.pl start [.ini Name]` dadruch wird ein Bot mit der angegeben ini datei gestartet.
So sind auch mehrere Bots gleichzeitig möglich (wenn zuvor eine zweite .ini datei mit Create erstellt wurde)
  /home/teamspeak/userbot/userbot.pl start userbot

* `./userbot.pl status` Zeigt alle laufenden Bots an mit ihrer Prozzes id und der verwendeten .ini Datei an

---------------------------------------------------------------------------------------------------------------------------------------

# Usage

**User Commands**

* `!help` - Zeigt alle eingestellten Befehle

* Die Userdefinierten Befehle welche in der INI-Datei angelegt werden. 
Beispiel:

```
befehle_list=!testa:9;!testb:10"
```
`!testa` wird dem User die Gruppe mit der id `9` zuweisen. 
`!testb` zu der Gruppe mit der id `10`. 
`!testa-del` entfernt den User aus der Gruppe mit der id `9`. 
Analog mit `!testb-del`.
Die möglichkeit `-del` kann in der ini Datei mit `disabledel=1` deaktiviert werden.

**Admin Befehle** 
*Werden nur Nutzern angezeigt/ermöglicht deren UUID als Parameter in der `admin_list` in der INI eingetragen sind.*

* `!debug` schaltet das Debug ein. Bei erneuter eingabe schaltet es dies wieder aus. Es wird eine "debug.txt" erstellt.
Manuell einschalten ist im Skript in Zeile 18 einstellen um ein dauerhaftes Debug ein oder aus zu schalten.

* `!movebot=to_channelid` - Verschiebt den Bot in die angegebene Channel id. Dort sind dann die Befehle ausführbar.

* `!movetemp=to_channelid` - Verschiebt alle temporären-vorhande-Channel zu der angegeben Channel-ID (als Sub-Channel).

* `!reload` - Lädt die Config Datei neu (nicht das Script selbst!)

* `!quit` beendet den Bot (löscht auch die .pid datei. Dies ist beim manuellen `kill` nicht fer Fall => kein Cleanup.)


Bei fragen oder Problemen: info[at]mzhost.de
=>Bei Problemen: Problem beschreiben, Debug einschalten und die erstellte Datei als Anhang beifügen.
*Alterantiv Issue auf Github.*

Germany - 2013
