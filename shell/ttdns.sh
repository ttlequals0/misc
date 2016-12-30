#!/bin/bash

function ttdns {
            if [ -z "$1" ] && [ -z "$2" ]; then
				echo -e "Usage: Command Host"
				echo -e "To look up IP type echo Host"
			else
				unset OCTET2 OCTET3 OCTET4	
				HOST=$(echo "$2" | tr '[:upper:]' '[:lower:]')
				COMMAND=$1
				OCTET1=10
				if [[ $HOST == m-* ]] ; then
					HOSTDC=${HOST:0:4}
				else
					HOSTDC=${HOST:0:2}
				fi

				case $HOSTDC in
					[Aa][Rr]) OCTET2=102 ;;
					[Cc][Hh]) OCTET2=111 ;;
					[Ff][Rr]) OCTET2=127 ;;
					[Ss][Yy]) OCTET2=144 ;;
					[Ss][Gg]) OCTET2=143 ;;
					[Nn][Yy]) OCTET2=113 ;;
					[Ll][Nn]) OCTET2=126 ;;
					[Hh][Kk]) OCTET2=145 ;;
					[Tt][Kk]) OCTET2=142 ;;
					[Mm]-[Aa][Rr]) OCTET2=204 ;;
					[Mm]-[Ff][Rr]) OCTET2=206 ;;	
					[Mm]-[Cc][Hh]) OCTET2=205 ;;																	
				esac
				
				if [[ $HOST == m-* ]] ; then
					OCTET3=${HOST:4:1}
				else
					OCTET3=${HOST:2:1}
				fi
				
				if [[ $HOST == m-* ]] ; then
					if [[ $HOST == m-*vmh* ]] || [[ $HOST == M-*VMH* ]]; then
						OCTET4=${HOST:8:5}	
					elif [[ $HOST == m-*vm* ]] || [[ $HOST == M-*VM* ]]; then
						OCTET4=${HOST:7:5}
					elif [[ $HOST == m-*srv* ]] || [[ $HOST == M-*SRV* ]]; then
						OCTET4=${HOST:8:5}	
					elif [[ $HOST == m-*cap* ]] || [[ $HOST == M-*CAP* ]]; then
						OCTET4=${HOST:8:5}																						
					fi
				else	
					if [[ $HOST == *srv* ]] || [[ $HOST == *SRV* ]]; then
						OCTET4=${HOST:6:3}
					elif [[ $HOST == *vmh* ]] || [[ $HOST == *VMH* ]]; then
						OCTET4=${HOST:6:3}
					elif [[ $HOST == *vm* ]] || [[ $HOST == *VM* ]]; then
						OCTET4=${HOST:5:3}
					elif [[ $HOST == *cap* ]] || [[ $HOST == *CAP* ]]; then
						OCTET4=${HOST:6:3}							
					fi
				fi	

			IP="$OCTET1.$OCTET2.$OCTET3.$OCTET4"
			$COMMAND $IP
			fi
           } 

ttdns $1 $2

