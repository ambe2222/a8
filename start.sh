#!/bin/bash
echo "==================================================================="
echo "==================================================================="
echo "made and translated by ARV8n"
echo "suorce = yonggekkk , eooce , mtg"
echo "Please select an option:"
echo "==================================================================="
echo "==================================================================="

select option in "yonggekkk serv00 script" "eooce serv00 script" "serv00 MTproxy" "exit"
do
    case $option in
	"yonggekkk serv00 script")
	echo "yonggekkk serv00 script"
	bash <(curl -Ls https://raw.githubusercontent.com/ambe2222/a8/refs/heads/main/serv%201/serv00.sh)
	;;
 	"eooce serv00 script")
  	echo "eooce serv00 script"
   	bash <(curl -Ls https://raw.githubusercontent.com/ambe2222/a8/refs/heads/main/serv%202/sb_serv00.sh)
    	;;
     	"serv00 MTproxy")
      	echo "serv00 MTproxy"
       	bash <(curl -Ls https://raw.githubusercontent.com/ambe2222/a8/refs/heads/main/mt.sh)
	;;
	"exit")
	echo "Exiting the program"
            break
            ;;
	esac
done
