#!/bin/ksh
#*******************************************************************************
# D e s c r i p t i o n
#*******************************************************************************
# Scriptname     : ap_wash.sh
# Current version: 2.0
# Function       : Clean old logfiles.
#                  First old logfiles are gzipped,
#                  then very old files are deleted.
#                  Last (when applicable) empty directories are removed.
# Location       : Location of stopwebsphere.sh
# Parameters     : -
# Calls scripts  : sb_cln_grw.sh
# Called by      : stopwebsphere.sh
#
#*******************************************************************************
# C h a n g e   l o g
#*******************************************************************************
# Version  Date        Name              Description
# -------  ----------  ----------------  ---------------------------------------
#    1.00  10-01-2011  Ivo Breeden       Eerste versie
#    1.01  25-02-2011  Ivo Breeden       Maak gebruik van standaard script
#                                        sb_cln_grw.sh
#    1.02  03-03-2011  Ivo Breeden       Toev: zip ${wasbase}/???/log/jacl.
#                                        Ruim ${wasbase}/???/log/jacl op als
#                                        er meer dan 5MB staat.
#                                        In http logdir staat ook pid file,
#                                        die mag niet gezipped worden.
#                                        Zip age 3 --> 15 dagen.
#    1.03  19-05-2011  Ivo Breeden       Change: Zip and clean the stop/start
#                                        Er werd teveel logging geproduceerd
#                                        omdat er teveel directories waren
#                                        waar niets gedaan hoefde te worden.
#                                        Daarom wordt nu met `find` een selectie
#                                        gemaakt van directories waar zip
#                                        of erase moet worden uitgevoerd.
#    1.04  22-06-2011  Ivo B/Ali Kokhan  Toev: Ditzo directories.
#    1.05  28-06-2011  Ivo Breeden       Change: efficiency verbetering:
#                                        eerst verwijderen, dan pas zippen.
#                                        (I.p.v. omgekeerd.)
#    1.06  06-07-2011  Ivo Breeden       Change: geparameteriseerd.
#                                        Directories staan nu in *.ini file.
#    1.07  14-07-2011  Ivo Breeden       Diverse verbeteringen.
#    1.08  02-09-2015  Ivo Breeden       Aangepast voor algemeen gebruik, dus
#                                        niet meer voor WAS. $wasid veranderd
#                                        in LOGNAME.
#    2.00   15-06-20176 Anibal Ojeda     Making translation to English
#*******************************************************************************
# ap_wash.sh is a front-end for the general cleanup script sb_cln_grw
################################################################
# Usage: sb_cln_grw -a{a|e|h|s|z} -d -n<num> -p<pattern> -s<source> [-t<target>] [-x]
#
#  -a {a|e|h|s} a=archive e=expire h=history s=shrink
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


# Invoke initialization, common to stop & start scripts
#
# First retrieve real location of script
if [[ -L ${0} ]]; then
  ls -l ${0}|read x x x x x x x x x x linkdir
  linkdir=$(dirname ${linkdir})
else
  linkdir=$(cd $(dirname ${0}) && pwd -P)
fi

scriptbase=$(basename ${0})
# scriptpure is without .sh suffix (used to find the
#   accompanied .ini file)
scriptpure=${scriptbase%.sh}

# Parameters: 1 possible parameter: -sim
if [[ $1 == "-sim" ]] ; then
  export sim='echo '
  echo "Simulatie (er wordt niet echt iets verwijderd):"
fi

################################################################
#
# Functions
#
# non_recursive_du() shows disk usage (du) of a directory
#                    without de subdirectories in bytes
#                    Only regular files are counted,
#                    not symbolic links, directories,
#                    special files or hidden files (whose
#                    name starts with '.').
# explanation:
#  ls -l shows a list of files and directories.
#  if the first column starts with "-" it is a file,
#  and the size in bytes is added to produce the result.
#
function non_recursive_du {
  ls -l $1 |
  awk 'BEGIN                   {resultaat=0}
       substr($1, 1, 1) == "-" {bytes=$5; resultaat+=bytes}
       END                     {printf("%d\n", resultaat)}'
}

#
################################################################
# Simple cleanup; cleanup files in one directory
# Files, older than ${DELAGE} days are deleted.
# Files, older than ${ZIPAGE} days are zipped.
#
function wash_simple {
  DIRECTORY=${1}
  ZIPAGE=${2}
  DELAGE=${3}
  if [ -z "${ZIPAGE}" ]
  then
    ZIPAGE=-1
  fi
  if [ -z "${DELAGE}" ]
  then
    DELAGE=-1
  fi

  # Expand wildcards and substitute variables
  set $(eval echo ${DIRECTORY})
  for dir in "${@}"
  do
    if [ -d "${dir}" ]
    then
      if (( ${DELAGE} >= 0 ))
      then
        # is ther work to do? (this is to prevent abundant logging)
        todo=$(find "${dir}" ! -name "$(basename "${dir}")" -prune -type f -mtime +${DELAGE}  -print| head -1)
        if [ ! -z "${todo}" ]
        then
          if [[ -z ${sim} ]]
          then
            #Als $sim leeg is, dan met -x (execute) optie. Anders niet.
            ${linkdir}/sb_cln_grw.sh -a e -n ${DELAGE} -s "${dir}" -x
          else
            ${sim}${linkdir}/sb_cln_grw.sh -a e -n ${DELAGE} -s "${dir}"
            ${linkdir}/sb_cln_grw.sh -a e -n ${DELAGE} -s "${dir}"
          fi
          echo '================================================================================'
        fi
      fi
      if (( ${ZIPAGE} >= 0 ))
      then
        # is ther work to do? (this is to prevent abundant logging)
        todo=$(find "${dir}" ! -name "$(basename "${dir}")" -prune -type f -mtime +${ZIPAGE} ! -name '*.gz' -print| head -1)
        if [ ! -z "${todo}" ]
        then
          if [[ -z ${sim} ]]
          then
            #Als $sim leeg is, dan met -x (execute) optie. Anders niet.
            ${linkdir}/sb_cln_grw.sh -a z -n ${ZIPAGE} -s "${dir}" -x
          else
            ${sim}${linkdir}/sb_cln_grw.sh -a z -n ${ZIPAGE} -s "${dir}"
            ${linkdir}/sb_cln_grw.sh -a z -n ${ZIPAGE} -s "${dir}"
          fi
          echo '================================================================================'
        fi
      fi
    fi
  done
}

#
################################################################
# Recursive cleanup; cleanup files in subdirectories.
# (And te directory itself.) Delete empty directories.
#
function wash_recursive {
  DIRECTORY=${1}
  ZIPAGE=${2}
  DELAGE=${3}
  if [ -z "${ZIPAGE}" ]
  then
    ZIPAGE=-1
  fi
  if [ -z "${DELAGE}" ]
  then
    DELAGE=-1
  fi

  # Expand wildcards and substitute variables
  set $(eval echo ${DIRECTORY})
  for dir in "${@}"
  do
    # Process subdirectories of the expanded $DIRECTORY(s)
    find "${dir}" -path "*lost+found" -prune -o  -type d | while read sdir
    do
      # do not try to process lost+found directories
      if [[ "${sdir}" = *lost+found ]]
      then
        continue
      else
        wash_simple "${sdir}" ${ZIPAGE} ${DELAGE}
        # Remove empty directories
        if (( $(ls -a "${sdir}" |wc -l) == 2 ))  # only . and ..
        then
          ${sim}rmdir "${sdir}"
          echo "Removed empty directory ${sdir}"
          echo '================================================================================'
        fi
      fi
    done
  done
}

################################################################
# Cleanup to maximum size: first old files are zipped.
# Then as long as the maximum size is exceeded, the oldest
# file is deleted.
# Only regular files are counted, not symbolic links, directories,
# special files or hidden files (whose name starts with '.').
#
function wash_to_size {
  DIRECTORY=${1}
  ZIPAGE=${2}
  MAXSIZE=${3}
  if [ -z "${ZIPAGE}" ]
  then
    ZIPAGE=-1
  fi
  if [ -z "${MAXSIZE}" ]
  then
    MAXSIZE=-1
  fi

  # Expand wildcards and substitute variables
  set $(eval echo ${DIRECTORY})
  for dir in "${@}"
  do
    if [ -d "${dir}" ]
    then
      # Start the zip program on the directory
      wash_simple "${dir}" ${ZIPAGE} -1
      #
      # Determine the size of all files in the directory
      totalsize=$(non_recursive_du "${dir}")
      if (( ${MAXSIZE} > 0 ))
      then
        if (( ${totalsize} > ${MAXSIZE} ))
        then
          cd "${dir}"
          print "Directory ${dir} bevat ${totalsize} bytes. Directory wordt geschoond tot onder ${MAXSIZE} bytes."
          let teveelB=${totalsize}-${MAXSIZE}
          # the string "victims" will contain files to be deleted
          victims=""
          # list files, oldest first
          ls -ltr | while read RWX x x x huidigefileB x x x bestand
          do
            if [[ ${RWX} == -* ]]  # if it is a regular file
            then
              # mind the quotes; a filename may contain spaces
              victims=${victims}\"${bestand}\"" "
              let teveelB=${teveelB}-${huidigefileB}
              # if enough bytes have been gathered for cleanup, then quit
              if (( ${teveelB} <= 0 ))
              then
                break
              fi
            fi
          done
          echo "De volgende files worden verwijderd in ${dir}:"
          # the string $victims may be large, so don't rely
          # on `ls -l $victims`. The same goes for remove.
          cat <<EOF |xargs ls -l
          ${victims}
EOF
          cat <<EOF |xargs ${sim}rm -f
          ${victims}
EOF
          echo '================================================================================'
          # back to the directory where the `if` started
          cd -   >/dev/null
        fi
      fi
    fi
  done
}

#
################################################################
# Touch: touch files to give them a new filestamp.
# This is to prevent open files to be zipped or deleted.
# Caveat: it does not have the desired result when directories
# are cleaned with zipage=0 or delage=0.
# Overall this is not a very good solution. But it is a
# practical solution.
#
function wash_touch {
  BESTAND=${1}

  # Expand wildcards and substitute variables
  set $(eval echo ${BESTAND})
  for ffile in "${@}"
  do
    if [ -f "${ffile}" ]
    then
      ${sim}touch "${ffile}"
      echo "File ${ffile} touched."
      echo '================================================================================'
    fi
  done
}

#
# End Functions
################################################################
# Start Script
#

# Read the ini file
#
awk -F: 'substr($1, 1, 1) != "#" {printf "%s %s %s %s %s\n", $1, $2, $3, $4, $5}' ${linkdir}/${scriptpure}.ini |
  while read Pwasid Paction Pzip Pdelete Pdirectory
  do
    # process the line if this environment (LOGNAME) is addressed
    if (( $(expr length ${LOGNAME}) == $(expr match ${LOGNAME} "${Pwasid}") ))
    then
      case ${Paction} in
      S|s)
        wash_simple "${Pdirectory}" ${Pzip} ${Pdelete}
        ;;
      R|r)
        wash_recursive "${Pdirectory}" ${Pzip} ${Pdelete}
        ;;
      M|m)
        wash_to_size "${Pdirectory}" ${Pzip} $((${Pdelete} * 1024))
        ;;
      T|t)
        wash_touch "${Pdirectory}"
        ;;
      *)
        print ERROR: invalid action in ${scriptpure}.ini: ${Paction}
        ;;
      esac
    fi
  done

#
# End Script
################################################################
