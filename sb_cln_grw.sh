#!/bin/ksh
#!/usr/bin/ksh
# bron: unix2004:/usr/local/bin >> cat sb_cln_grw
################################################################
# Module    : sb_cln_grw
# Author    : G. Mosterd
# Date      : Thu Jan 25 08:22:01 NFT 2007
################################################################
# Modifications
################################################################
# Date v      : 24-feb-2011
# Author      : Ivo Breeden
# Version     : 1.1
# Description : Add: option z=zip files. (using gzip)
################################################################
# Date        : 11-mar-2011
# Author      : Ivo Breeden
# Version     : 1.2
# Descrition  : Spaces in filenames are now handeled correctly.
################################################################
# Date       : 15-june-2016
# Author     : Anibal Ojeda
# Version    : 1.3
# Descrition : Changes to English
################################################################
# Usage: sb_cln_grw -a{a|e|h|s|z} -d -n<num> -p<pattern> -s<source> [-t<target>] [-x]
#
#  -a {a|e|h|s|z} a=archive e=expire h=history s=shrink z=zip
#    a = Move all files in -s<source-dir> older than -n<days> to -t<target-dir>
#    e = Delete all files in -s<source-dir> older than -n<days>
#    h = Rename all files in -s<source-dir> older than -n<days> to file.history
#    s = Shrink the -s<source-file> to the last -n<lines>
#    z = Zip all files in -s<source-dir> older than -n<days>
#  -d Select directories also with -a{a|e|h}
#  -n {NUMERIC-VALUE} number of days -a{a|e|h|z} or number of lines -a{s}
#  -p {Select-pattern} not with -a{s}
#  -s {source-object} directory with -a{a|e|h|z} or file with -a{s}
#  -t {target-directory} only with -a{a}
#  -x Execute mode. Without this option run is report only
################################################################
#  Verplaats alle bestanden ouder dan 30 dagen
#  van /appl/xxx00t/log naar /appl/xxx00t/archief
#  sb_cln_grw -aa -n30 -s/appl/xxx00t/log -t/appl/xxx00t/archief -x
#
#  Toon te Verwijderen bestanden ouder dan 60 dagen in /appl/yyy00p/log
#  sb_cln_grw -ae -n60 -s/appl/yyy00p/log
#
#  Toon te Verwijderen bestanden en directories ouder dan 300 dagen
#  met string "log" in de naam in directory /appl/yyy00p/log
#  sb_cln_grw -ae -n60 -d -plog -s/appl/yyy00p/log
#
#  Verwijder alle bestanden ouder dan 60 dagen uit /appl/yyy00p/log
#  sb_cln_grw -ae -n60 -s/appl/yyy00p/log -x
#
#  Hernoem alle bestanden ouder dan 45 dagen in /appl/yyy00p/log naar file.history
#  sb_cln_grw -ah -n45 -s/appl/xxx00t/log -x
#
#  Reduceer /appl/xxx00t/log/big_logfile tot de laatste 10000 regels
#  sb_cln_grw -as -n10000 -s/appl/xxx00t/log/big_logfile -x
#
#  Zip alle bestanden ouder dan 45 dagen in /appl/yyy00p/log
#  sb_cln_grw -az -n45 -s/appl/xxx00t/log -x
#
################################################################
# Init default variables
################################################################
CURDIR=$(dirname $0)
CURFIL=$(basename $0)
[ "$CURDIR" = '.' ] && CURDIR=$(pwd)

# Init global variables
ACTION=""
NUMBER=""
SRCOBJ=""
TARDIR=""
PATTRN=""
SUBDIR=""
EXECUTE=""
RUNTXT=""
TMPFIL="/tmp/.$CURFIL.$$.tmp"
TRGFIL="/tmp/.$CURFIL.$$.trg"
TRGDAT=$(date)
CLIPAR="$*"

# trap "rm -f $TRGFIL TMPFIL" 0-255   # Opruimen bij exit
trap "rm -f $TRGFIL TMPFIL" 1 2 3 4 5 6 7 8 10 11 12 13 14 15 16 17 18 19 20   # Opruimen bij exit

# #############################################
# Function declarations
# #############################################
# #############################################
# Usage display
# #############################################
Usage_Err()
{
  [ 0$1 -eq 0 ] && return
  cat<<EOT
Usage: $CURFIL -a{a|e|h|s|z} -d -n<num> -p<pattern> -s<source> [-t<target>] [-x]

 -a {a|e|h|s|z} a=archive e=expire h=history s=shrink
   a = Move all files in -s<source-dir> older than -n<days> to -t<target-dir>
   e = Delete all files in -s<source-dir> older than -n<days>
   h = Rename all files in -s<source-dir> older than -n<days> to file.history
   s = Shrink the -s<source-file> to the last -n<lines>
   z = Zip all files in -s<source-dir> older than -n<days>
 -d Select directories also with -a{a|e|h}
 -n {NUMERIC-VALUE} number of days -a{a|e|h|z} or number of lines -a{s}
 -p {Select-pattern} not with -a{s}
 -s {source-object} directory with -a{a|e|h|z} or file with -a{s}
 -t {target-directory} only with -a{a}
 -x Execute mode. Without this option run is report only

EOT
  ErrChk $*
}

# #############################################
# Error check
# #############################################
ErrChk()
{
 if [ 0$1 -ne 0 ]
 then
   echo xxxxxxxxx
   echo x ERROR x
   echo xxxxxxxxx
   LogMsg "RC=$*"
   exit $1
 fi

}

# #############################################
# Log message
# #############################################
LogMsg()
{
  print "$(date +"%d/%m/%y %H:%M:%S"): $*"
}

# #############################################
# Warning check
# #############################################
WrnChk()
{
 if [ 0$1 -ne 0 ]
 then
   banner WARNING
   LogMsg "RC=$*"
 fi
 return $1
}

# #############################################
# Calculate previous date
# #############################################
CreDatTrg()
{
  echo TRIGGER-DATE:$(date --date="$1 days ago")

  # Create trigger
  touch --date "$1 days ago"  $TRGFIL
  ErrChk $? "ERROR: touch --date \"$1 days ago\" $TRGFIL FAILED!"
}

# ####################################################
# Check CLI Parameters
# ####################################################
ChkPar()
{
  [[ $# -eq 0 ]] && Usage_Err 1 "ERROR: No parameters specified PRUTSER!"

  #set -x


  # Parse command line into arguments & check result of parsing
  set -- `getopt a:dn:p:s:t:x $*`
  Usage_Err $? "ERROR: Invalid parameter $CLIPAR specified DODO!"

  typeset -l junc # lower case

  while [ "$1" != -- ]
  do
    case $1 in
    -a)     # Action
            ACTION=$2
            [[ $ACTION = a ]] && RUNTXT="ARCHIVE"
            [[ $ACTION = h ]] && RUNTXT="HISTORY"
            [[ $ACTION = e ]] && RUNTXT="EXPIRE"
            [[ $ACTION = s ]] && RUNTXT="SHRINK"
            [[ $ACTION = z ]] && RUNTXT="ZIP"
            shift   # next flag
            ;;
    -d)     # Process subdirs
            SUBDIR=1
            ;;
    -n)     # Numeric parameter
            NUMBER=$2
            shift   # next flag
            ;;
    -p)     # Pattern parameter
            PATTRN=$2
            shift   # next flag
            ;;
    -s)     # Source directory or file
            SRCOBJ=$2
            shift   # next flag
            ;;
    -t)     # Target directory
            TARDIR=$2
            shift   # next flag
            ;;
    -x)     # EXECUTE
            EXECUTE=1
            ;;
    *)      # Parameter error
            Usage_Err 1 "ERROR: Invalid parameter specified $1 DIPSTICK!"
            ;;
    esac
    shift   # next flag
  done

  # Kontrole verplichte velden
  [[ $ACTION != @(a|e|h|s|z) ]] && Usage_Err 1 "ERROR: Invalid action specified (-a $ACTION ) KNOEIER!"

  # Kontrole bron object aanwezig
  [[ ! -n $SRCOBJ ]] && Usage_Err 1 "ERROR: Source (-s <FILE|DIR> ) not specified PRUTSER!"

  #[[ $SRCOBJ != /appl/* ]] && Usage_Err 1 "ERROR: Source object must be part of /appl/ KNUPPEL!"

  E_TXT="Expiration days"

  # Kontrole archiveren / expireren / history / reduceren / zippen
  if [[ $ACTION = @(a|e|h) ]]
  then
    # archiveren / expireren / history / zippen
    if [[ ! -d $SRCOBJ ]]
    then
      Usage_Err 1 "ERROR: Source (-s <DIR> ) is no directory KNUPPEL!"
    fi
    if [[ $ACTION = a ]]
    then
      if [[ ! -n $TARDIR ]] || [[ ! -d $TARDIR ]]
      then
        Usage_Err 1 "ERROR: Invalid directory (-t $TARDIR ) SHAKEHEAD!"
      fi
    fi
  elif [[ $ACTION = s ]]
  then
    # reduceren
    if [[ ! -f $SRCOBJ ]]
    then
      Usage_Err 1 "ERROR: Accessing file ( -s $SRCOBJ ) BOY!"
    fi
    E_TXT="Reduction "
  elif [[ $ACTION = z ]]
  then
    # Zippen
    if [[ -n $SUBDIR ]]
    then
      Usage_Err 1 "ERROR: Cannot zip directories NUT!"
    fi
    E_TXT="Zipping "
  fi

  # Kontrole number
  if [[ $NUMBER != +([0-9]) ]]
  then
    Usage_Err 1 "ERROR: $E_TXT number invalid (-n $NUMBER ) BUFFEL!"
  fi
}

# #############################################
# Loop thru directory
# #############################################
Process_Directory()
{
  echo "SOURCE-DIR  :$SRCOBJ"
  echo "TARGET-DIR  :$TARDIR"
  echo "SUBDIRS-TO  :$SUBDIR"
  echo "PATTERN     :$PATTRN"
  echo "TRIGGER-DAY :$NUMBER"

  # Create file with dir-content
  ls -a $SRCOBJ >$TMPFIL
  ErrChk $? "ERROR: ls >$TMPFIL FAILED!"

  # Create date trigger
  CreDatTrg $NUMBER

  echo "##### SELECTED OBJECTS FOR $RUNTXT #####"

  # Loop thru files in directory
  while read d_obj
  do
    # Make fullpath
    chk_obj=$SRCOBJ/$d_obj

    # Skip current and parent dir
    [[ $d_obj = . ]] || [[  $d_obj = .. ]] && continue

    # When file mode Process files only
    [[ ! -n $SUBDIR ]] && [[ ! -f $chk_obj ]] && continue

    # Select specified pattern only
    [ $PATTRN ] && [[ $d_obj != *$PATTRN* ]] && continue

    # Select files older trigger only
    [[ $chk_obj -nt $TRGFIL ]] && continue

    # Select non history files only in history mode
    [[ $ACTION = h ]] && [[ $d_obj = *.history ]] && continue

    # Do not zip zipped files
    [[ $ACTION = z ]] && [[ $d_obj = *.gz ]] && continue

    ls -dl "$chk_obj"

    # Select action only in execute mode
    if [ $EXECUTE ]
    then
      if   [[ $ACTION = a ]]
      then
        mv "$chk_obj" $TARDIR
        ErrChk $? "ERROR: mv $chk_obj $TARDIR FAILED!"
      elif [[ $ACTION = e ]]
      then
        rm -rf "$chk_obj"
        ErrChk $? "ERROR: rm -f $chk_obj FAILED!"
      elif [[ $ACTION = h ]]
      then
        mv "$chk_obj" "${chk_obj}".history
        ErrChk $? "ERROR: mv $chk_obj ${chk_obj}.history FAILED!"
      elif [[ $ACTION = z ]]
      then
        gzip "$chk_obj"
        ErrChk $? "ERROR: gzip $chk_obj FAILED!"
      fi
    fi
  done<$TMPFIL
  ErrChk $? "ERROR: Read $TMPFIL FAILED!"
}

# #############################################
# Shrink file
# #############################################
Shrink_File()
{
  echo "SOURCE-FILE :$SRCOBJ"
  echo "SHRINK-LINES:$NUMBER"

  # Show file before
  echo "BEFORE: $(ls -l $SRCOBJ)"
  tail -$NUMBER $SRCOBJ > $TMPFIL
  ErrChk $? "ERROR: tail -$NUMBER $SRCOBJ FAILED!"

  if [ $EXECUTE ]
  then
    cp $TMPFIL $SRCOBJ
    ErrChk $? "ERROR: cp $TMPFIL $SRCOBJ FAILED!"
  fi

  # Show file after
  echo "AFTER : $(ls -l $SRCOBJ)"
}

########################################
########################################
########################################
# MAIN
########################################
########################################
########################################
LogMsg "START: $CURFIL"

echo "RUN-PAR     :$CURFIL $CLIPAR"

# Perform CLI-checks
ChkPar $*

[ $EXECUTE ] && RUNMODE="EXECUTE" || RUNMODE="REPORT"

echo "RUNMODE     :$RUNMODE"
echo "ACTION      :$RUNTXT"

# archiveren / expireren / history or reduce file
if [[ $ACTION != s ]]
then
  Process_Directory
else
  Shrink_File
fi

rm -f $TMPFIL $TRGFIL 2>&1

LogMsg "EINDE: $CURFIL"
