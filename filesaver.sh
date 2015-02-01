#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # #
# EXIT STATUS:									#
#  - 0:	Programma terminato correttamente		#
#  - 2:	Parametri assenti o incorretti			#
#  - 3:	Permessi insufficienti					#
#												#
# # # # # # # # # # # # # # # # # # # # # # # # #

# Dichiaro le variabili per i parametri
dest=""
sour=""
comp=0
tch=0
verb=0
min=0
max=0
subdir=0
declare -a exts

### Mostra l'help e termina con l'exit status che riceve come parametro
function usage {
	echo "utilizzo: `basename "$0"` [opzioni]
Esempio: `basename "$0"` -d /media/backup -s /home/`logname` -e .mp3 .ogg
copia tutti i file mp3 e ogg presenti nella cartella /home/`logname`
(e nelle sottocartelle) in /media/backup/home-`logname`_`date +"%Y%m%d-%H%M%S"`

Opzioni:
 -c, --compress			comprime il backup in un archivio Bzip2
				(nomebackup.tar.bz2).
 -d, --destination-directory	cartella di destinazione, DEVE avere permessi
				rwx
 -e, --extensions		estensioni file da copiare (case insensitive),
 				se non specificato copia tutti i file presenti
 -h, --help			mostra questo aiuto e esce
 -M, --max-size			esclude dal backup file di dimensioni maggiori
				di quella specificata (MB)
 -m, --min-size			esclude dal backup file di dimensioni minori di
				quella specificata (MB)
 -s, --source-directory		cartella da copiare, se non specificato copia
 				quella corrente. DEVE avere permessi rw-
 -t, --touch			aggiorna date di accesso e modifica e dei file
				creati. IGNORATO se usato --compress
 -V, --verbose			mostra informazioni per ogni file copiato

La sottocartella per il backup (o il file compresso) avra' nome:
percorso_data-ora, con formato data AAAAMMGG e formato ora OOMMSS"
	exit $1
}

### Controlla se la destinazione e' (una sottocartella di) quella sorgente
### Parametri: sorgente, destinazione
function isSubdir {
	leng1=${#1}
	leng2=${#2}
	# Il percorso della presunta sottocartella deve essere più lungo
	# dell'altro e contenerlo (es. /usr/ e /usr/bin)
	if test $leng1 -le $leng2 -a "\"$1\"" = "\"${2:0:$leng1}\""
	then
		return 1
	fi
	return 0
}

while test -n "$1" # Scorro tutti i parametri
do
	case "$1" in
	"--destination-directory"|"-d")
		shift # Prendo il parametro successivo per ottenere il percorso
		
		# mi assicuro che il percorso finisca con / (per il funzionamento di isSubdir)
		if test ${1:${#1}-1:1} = "/"
		then
			dest="$1"
		else
			dest="$1/"
		fi
		
		if !(test -d "$dest") # Controllo esistenza cartella
		then
			echo "Cartella di destinazione inesistente"
			exit 2
		elif !(test -r "$dest" -a -w "$dest" -a -x "$dest") # Controllo permessi
		then
			echo "Permessi insufficienti sulla cartella di destinazione"
			usage 3
		fi
		;;
	"--source-directory"|"-s")
		shift
		
		# mi assicuro che il percorso finisca con / (per il funzionamento di isSubdir)
		if test ${1:${#1}-1:1} = "/"
		then
			sour="$1"
		else
			sour="$1/"
		fi
		
		if !(test -d "$sour")
		then
			echo "Cartella di origine inesistente"
			exit 2
		elif !(test -r "$sour" -a -x "$sour")
		then
			echo "Permessi insufficienti sulla cartella di origine"
			usage 3
		fi
		;;
	"--extensions"|"-e")
		if !(test "." = "`echo "$2" | cut -c1`")
		then
			echo "Nessuna estensione specificata o formato non valido
Le estensioni devono iniziare con un punto"
			usage 2
		fi
		while test "." = "`echo "$2" | cut -c1`" # Cicla tutte le estensioni specificate
		do
			exts[${#exts[@]}]=${2:1}
			shift
		done
		;;
	"--compress"|"-c")
		comp=1
		;;
	"--touch"|"-t")
		tch=1
		;;
	"--verbose"|"-V")
		verb=1
		;;
	"--help"|"-h")
		usage 0
		;;
	"--min-size"|"-m")
		shift
		if (test "`expr ""$1"" - ""$1"" 2>/dev/null`" = "0" -a "$1" -gt 0) # Controllo se l'utente ha specificato un valore numerico
		then
			min="$1"
		else
			echo "Valore non corretto per min-size: "$1""
			usage 2
		fi
		;;
	"--max-size"|"-M")
		shift
		if (test "`expr ""$1"" - ""$1"" 2>/dev/null`" = "0" -a "$1" -gt 0) # Controllo se l'utente ha specificato un valore numerico
		then
			max="$1"
		else
			echo "Valore non corretto per max-size: "$1""
			usage 2
		fi
		;;
	*)
		echo "Parametro non valido: "\"$1\"""
		usage 2
	esac
	shift
done

if test -z "$dest"
then
	echo "Destinazione non specificata"
	usage 2
fi

# Se sorgente non specificata prendo la cartella corrente e verifico i permessi
if test -z "$sour"
then
	sour=`pwd`
	if !(test -r "$sour" -a -x "$sour")
	then
		echo "Cartella di origine inesistente o permessi insufficienti"
		usage 3
	fi
fi

comando="find \"$sour\""

# Controllo se la destinazione e' una sottocartella di quella sorgente
if !(isSubdir "$sour" "$dest")
then
	echo "La cartella di destinazione e' una sottocartella di quella sorgente, verranno
saltati i file appartenenti al backup stesso per evitare duplicati"
	sleep 3
	subdir=1
fi

# Creo il nome del backup
if test "/" = "${sour:0:1}"
then
	backup_name="${sour:1:${#sour}-2}"
else
	backup_name="$sour"
fi
backup_name=`echo "${backup_name:0:${#backup_name}}" | sed s?/?-?g`_`date +"%Y%m%d-%H%M%S"`

# le estensioni da passare al find
if test ${#exts[@]} -gt 0
then
	comando="$comando \("
	for ext in "${exts[@]}"
	do
		comando="$comando -iname \*.$ext -o"
	done
	comando="${comando:0:${#comando}-3} \)"
fi

# le dimensioni specificate
if test $min -gt 0
then
	comando="$comando -size +$(($min-1))M"
fi
if test $max -gt 0
then
	comando="$comando -size -`expr $max + 1`M"
fi

# Se la destinazione è una sottocartella della sorgente rischierei un loop
# con find o comunque creerei sicuramente dei duplicati, quindi aggiungo al
# find "ignora file nella cartella del backup". Potrei evitare di controllare
# e farlo automaticamente ma risparmio un controllo per ogni file se non sono
# sottocartelle
if test $subdir -eq 1
then
	comando="$comando ! -path \"${dest}${backup_name}/*\""
fi

# Specifico l'output del find in modo che gestisca bene file con nomi "strani" e
# escludo le cartelle (evito errori di file già esistente e di copiare cartelle vuote)
comando="$comando ! -type d -print0 "

# Divido i casi in cui devo creare un archivio da quello di copiare semplicemente
if test $comp -gt 0
then
	backup_name="${backup_name}.tar"
	fullname="${dest}${backup_name}"
	if (eval "tar cf \"$fullname\"  --files-from=/dev/null 2>/dev/null")
	then
		# Informo di aver creato l'archivio
		if test $verb -gt 0
		then
			echo "Archivio creato"
		fi
	else
		echo "Errore durante la creazione dell'archivio"
	fi
	
	while IFS= read -r -d $'\0' file; do
		if eval "test -r '$file'" # Controllo se ho i permessi per poter proseguire con l'eliminazione
		then
			if (eval "cd '$sour' && tar rf '$fullname' '${file/#"$sour"}'")
			then
				if test $verb -gt 0
				then
					echo "Archiviato "$file""
				fi
			else
				echo "Errore durante l'archiviazione di "$file""
			fi
		else
			echo "Permessi insufficienti per "$file""
		fi
	done < <(eval "$comando")
	
	echo "Compressione dell'archivio..."
	
	if !(eval "bzip2 '$fullname' 2>/dev/null")
	then
		echo "Errore durante la compressione di '$fullname'"
	fi
	
else
	fulldest="${dest}${backup_name}/"
	while IFS= read -r -d $'\0' file; do
		if eval "test -r '$file'" # Controllo se ho i permessi per poter proseguire con l'eliminazione
		then
			path="$(dirname "$file")/"
			newPath=\"${fulldest}${path/#"$sour"}\"
			eval "mkdir -p $newPath"
			
			# Copio i file mantenendo anche informazioni accessorie (date modifica, accesso, permessi, ...)
			if !(eval "cp -p \"$file\" $newPath")
			then
				echo "Errore durante la copia del file \"$file\""
			fi
			
			# Aggiorno date di modifica e accesso dei file
			if test $tch -gt 0
			then
				if !(eval "touch -c -f $newPath 2>/dev/null")
				then
					echo "Errore durante l'aggiornamento delle date di $newPath"
				fi
			fi
			
			# Stampo informazioni sull'operazione
			if test $verb -gt 0
			then
				echo "Copiato \"$file\""
			fi
		else
			echo "Permessi insufficienti per "$file""
		fi
	done < <(eval "$comando")
fi
