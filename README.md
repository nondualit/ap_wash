# wash_script

Working on the English README file

Datum		04-08-2011

Update		04-08-2011
Script		Voor Beheer – Schoning
Opdracht		Ruim periodiek oude bestanden op
Door		Ivo Breeden

Inleiding
Dit script ruimt directories op. Het is vooral voor directories met logfiles die anders ongeremd zouden blijven groeien. In principe zullen bestanden in de aangegeven directories na korte tijd (bijv. een week) gezipped worden. Na langere tijd worden de bestanden verwijderd. Een en ander is instelbaar.

Dit script kan worden opgenomen op de wasstop/start scripts van WebSphere.

Handleiding
Usage: ~/was_wash  [-sim]
Als de optie –sim wordt meegegeven, dan wordt een schoning gesimuleerd. In de logfile (waarvan de naam wordt getoond) staat een verslag van de commando’s die zouden worden uitgevoerd.
Zonder opties wordt een schoning uitgevoerd. De naam van de logfile wordt getoond op het scherm (~/log/<datum>/<tijd>_was_wash.log).

In dezelfde directory als waar was_wash.sh staat, moet ook een was_wash.ini staan. In die file wordt gedefiniëerd wat er geschoond wordt en hoe.
# Info:     Regels die met een # beginnen zijn commentaar.
#           Iedere regel bevat 5 velden, gescheiden door ":". De velden zijn:
#
# WasID:    was02, was03, was04, ...
# Action:   S (simple) schoont alleen de gegeven directory. (Maar omdat de
#             directory padnaam wildcards mag bevatten, kunnen het toch meer
#             directories zijn.)
#           R (recursive) schoont de gegeven directory en onderliggende
#             directories. Verwijdert lege directories. Schoont geen
#             lost+found directories.
#           M (Max KB) als de directory na het zippen van bestanden
#             nog steeds meer dan het opgegeven aantal KB bevat,
#             worden de oudste bestanden verwijderd totdat er minder dan
#             het opgegeven aantal KB over is.
#           T Touch. Voor open files en files die niet gezipped of verwijderd
#             mogen worden. In plaats van een directory wordt een filenaam
#             opgegeven en die file krijgt met `touch` een timestamp van "nu".
#             Zip en Delete worden genegeerd.
#             Het werkt helaas niet als de ZIP of DELETE  van een volgende
#             {S|R|M} action op "0" staan.
#             (Het is geen mooie oplossing, maar wel een practische.)
# Zip:      leeftijd in dagen waarna en file gezipped mag worden.
#             -1 betekent: niet zippen.
# Delete:   bij Action S of R: leeftijd in dagen waarna een file verwijderd moet
#           worden. -1 betekent niet verwijderen.
# Delete:   bij Action=M: maximum bytes die files in een directory mogen hebben.
#           -1 betekent niet verwijderen.
# Directory:Pad naar Directory. Mag variabelen en wildcards bevatten, maar geen
#           spaties. Bij de T (Touch) action is dit het pad van een filenaam.
#
# Pas op:   De opgegeven regels worden één voor één uitgevoerd. Doordat
#           wildcards in de directory naam voor mogen komen, kan eenzelfde pad
#           vaker worden "behandeld". Bijv:
#             was00:S:  8:  60:${HOME}/???/log
#             was00:S:  8: 356:${HOME}/was/log
#           In de tweede regel worden logfiles geen 356 dagen bewaard omdat ze
#           door de eerste regel al na 60 dagen verwijderd worden.

Voorbeeld:
################################################################################
# WasID:Action:Zip:Delete:Directory
################################################################################
# WAS02 - geconsolideerd
#  Uitzonderingen: volgende files niet verwijderen of zippen
was02:T:  0:   0:/appl/was02${tgep}/IBMIHS/logs/httpd.pid
was02:T:  0:   0:${HOME}/log/heapcheck.log
was02:T:  0:   0:${HOME}/log/lpcheck.log
was02:T:  0:   0:/appl/was02${tgep}/alg/log/lp.pid
#  Opschoningsregels
was02:S:  8:  61:/appl/was02${tgep}/IBMIHS/logs
was02:R:  8: 365:${HOME}/log
was02:S:  5:  30:/appl/was02${tgep}/WebSphere/AppServer/heapdump
was02:S: 21:  -1:/appl/was02${tgep}/alg/log
was02:M:183:5120:/appl/was02${tgep}/[a-z][a-z,0-9][a-z]/log/jacl
was02:S:  8: 365:/appl/was02${tgep}/sgl/data/transfer/in/smartbox
was02:S:  8: 365:/appl/was02${tgep}/sgl/data/transfer/in/wvm
was02:S:  8: 365:/appl/was02${tgep}/sgl/data/transfer/out/smartbox/processed
was02:S:  8: 365:/appl/was02${tgep}/sgl/data/transfer/out/wvm/processed
was02:S:  8: 365:/appl/was02${tgep}/sli/data/source/_archive


Installatie handleiding
De volgende files moeten geplaatst worden:
•	was_wash.sh
•	was_wash.ini
•	sb_cln_grw.sh

Deze files horen bij was02* en dit00* in de directory:
•	/beheer/ob/was
Bij alle andere WebSphere installaties (was03, was04 enz.) in de directory:
•	/was/<versie>/was*/home/bin/

Templaten is niet nodig. Het script was_wash.sh haalt zijn omgevingsvariabelen uit het bestaande script stoa_websphere_ini.sh.

De logfiles zijn te vinden in ${HOME}/log/<datum>/<tijd>_was_wash.log.

Automatisch start/stop van het script
Maak en symbolic link naar het script in de home directory met de naam: was_wash.

Pas de file _stopoptions.*.txt (in dezelfde directory als het was_wash.sh script) aan. Voeg de volgende regel toe:
•	WasWash                ${HOME}/was_wash



Handmatig start van het script

~/was_wash
