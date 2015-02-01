#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # #
# EXIT STATUS:								#
#  - 0:	Programma terminato correttamente	#
#  - 2: Parametri assenti o incorretti		#
#  - 3: Permessi assenti o insufficienti	#
#											#
# # # # # # # # # # # # # # # # # # # # # # #
################################### SE DEI FILE HANNO I PERMESSI MA SI TROVANO IN UNA CARTELLA CHE NON LI HA
################################### VERRÀ DATO ERRORE SUL FILE (SENZA SPECIFICARE CHE IL PROBLEMA È NEI PERMESSI)
#VARIABILI
dir=""
declare -a exts
declare -a files
sec=0
quiet=0

function usage
{
	echo "Uso: `basename "$0"` [opzioni]
Elimina i file specificati dall'utente oppure quelli con una specifica
estensione.

	-d, --directoryname	nome della directory da cui eliminare i file,
				questa opzione NON puo' essere usata con -f
	-e, --extensions	estensioni dei file che s'intende eliminare,
				questa opzione puo' essere usata SOLO in 
				combinazione con -d
				Se non viene specificata cancella TUTTI i file
				presenti in -d
	-f, --filename		nome di uno o piu' file da cancellare, questa
				opzione NON puo' essere usata con -d
				E' consigliabile specificarlo come ultimo
				parametro, infatti interpreta quello che viene
				specificato dopo come nome di file A MENO CHE
				questo inizi con un \"-\"
	-h, --help		mostra questo aiuto e esce
	-s, --secure		sovrascrive il contenuto dei file da cancellare
				con una serie di caratteri casuali prima
				della cancellazione; se	specificata DEVE
				esser seguita da un'intero positivo
	-q, --quiet             cancella i file senza chiedere conferma
	
La funzione chiede conferma prima di procedere alla cancellazione, ed eventuale
sovrascrittura del file.
Si consiglia all'utente di eseguire un backup di tutti i file importanti prima
di procedere con la cancellazione.

Esempi:
- `basename "$0"` -d /home/Scrivania -e .mp3 .txt
Cancella tutti i file nella scrivania con estensione .mp3 e .txt
- `basename "$0"` -s 10 -f insert.c catalogo.pdf
Cancella i file specificati"
	exit $1
}

            ################ CONTROLLO PARAMETRI ################
            
while test -n "$1" 
do
	case $1 in
	"--directoryname"|"-d")
		shift 				#passo al parametro successivo
		dir="$1"
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
			exts[${#exts[@]}]=\"${2:1}\"
			shift
		done
	;;	
			
	"--help"|"-h")
		usage 0
	;;
	
	"--secure"|"-s")
		shift
		if (test "`expr ""$1"" - ""$1"" 2>/dev/null`" = "0" -a "$1" -gt 0) # Controllo se l'utente ha specificato un valore numerico
		then
			sec="$1"
		else
			echo "Valore non corretto: "$1""
			usage 2
		fi	
	;;
	
	"--filename"|"-f")
		while test -n "$2" -a "-" != "`echo "$2" | cut -c1`" # Salvo tutti i file specificati dall'utente
		do
			files[${#files[@]}]=\"$2\"
			shift
		done
	;;

	"--quiet"|"-q")
		quiet=1
	;;
	
	*)
		echo "Parametro non valido: "\"$1\"""
		usage 2
	esac
	shift
done

            ################ CONTROLLO CONFLITTI ################

# Controllo se l'utente ha specificato i parametri in contrasto
if test -n "$dir" -a ${#files[@]} -gt 0		# Controllo che non sia stato specificato sia -d che -f
then
	echo "Parametri in conflitto: -f e -d non possono essere usati assieme"
	usage 2
fi
if test ${#files[@]} -gt 0 -a ${#exts[@]} -gt 0
then
	echo "Parametri in conflitto: -f e -e non possono essere usati assieme"
	usage 2
fi

            ################ CONTROLLO PERMESSI ################

# Controllo la directory
if test -n "$dir"
then           
	if !(test -d "$dir")      # Controllo se la cartella specificata esiste
	then
		echo "Cartella non trovata, controllare se il percorso inserito e' corretto"
		exit 2
	elif !(test -r "$dir" -a -w "$dir" -a -x "$dir") # Controllo se ho i permessi per poter proseguire con l'eliminazione
		then
		echo "Permessi insufficienti per la cartella selezionata"
		exit 3
	fi
fi
# Controllo i file
if test ${#files[@]} -gt 0
then
	for (( c=0; c<${#files[@]}; c++))
	do
		if !(eval "test -e "${files[c]}"")      # Controllo se il file specificato esiste
		then
			echo ""${files[c]}" non trovato, controllare se il percorso inserito e' corretto"
			files[c]=""
		elif !(eval "test -r "${files[c]}" -a -w "${files[c]}"") # Controllo se ho i permessi per poter proseguire con l'eliminazione
			then
			echo "Permessi insufficienti per "${files[c]}""
			files[c]=""
		fi
	done
fi

            ################ INIZIO ELIMINAZIONE ################
            ################    directoryname    ################
            
if test -n "$dir"
then
	if test ${#exts[@]} -gt 0
	then
		for ext in "${exts[@]}"
		do
			command="find \"$dir\" -iname *.$ext -depth -print0 2>/dev/null"
			
			while IFS= read -r -d $'\0' file; do
				if eval "test -r "\"$file\"" -a -w "\"$file\""" # Controllo se ho i permessi per poter proseguire con l'eliminazione
				then
					files[${#files[@]}]=\"$file\"
				else
					echo "Permessi insufficienti per "$file""
				fi
			done < <(eval $command)
		done
	else
		command="find \"$dir\" -depth -print0 2>/dev/null"
			
		while IFS= read -r -d $'\0' file; do
			if eval "test -r "\"$file\"" -a -w "\"$file\""" # Controllo se ho i permessi per poter proseguire con l'eliminazione
			then
				files[${#files[@]}]=\"$file\"
			else
				echo "Permessi insufficienti per "$file""
			fi
		done < <(eval $command)
	fi
fi

REPLY="si"
if test ${#files[@]} -gt 0
then 
	for file in "${files[@]}"
	do
		if test -n "$file"
		then
			if test $quiet -eq 0
			then
				echo -n "Sicuro di voler eliminare il file $file"
				if test $sec -gt 0
				then
					echo -n " sovrascrivendolo"
				fi
				echo "?"
				read
			fi
			if test "${REPLY,,}" = "si" -o "${REPLY,,}" = "s" -o "${REPLY,,}" = "yes" -o "${REPLY,,}" = "y"
			then
				eval "shred -un $sec $file 2>/dev/null"
				if test $? -gt 0
				then
					if eval "test -d "$file""
					then
						if !(eval "rmdir "$file" 2>/dev/null")
						then
							echo "La cartella "$file" non e' vuota!"
						fi
					else
						echo "Si e' verificato un errore con "$file""
					fi
				fi
			else
				echo "Saltato $file"
			fi
		fi
	done
fi
