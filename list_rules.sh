echo "===========THE LIST OF THE RULES==========="
echo
echo "++++++++++++++DOCKER USER++++++++++++++++++"
iptables -L DOCKER-USER -nv --line-numbers
echo "++++++++++++++PREROUTING++++++++++++++++++"
iptables -t nat -L PREROUTING -n --line-numbers
echo "+++++++++++++++++OUTPUT++++++++++++++++++"
iptables -t nat -L OUTPUT -n --line-numbers
echo "+++++++++++++++POSTROUTING+++++++++++++++"
iptables -t nat -L POSTROUTING -n --line-numbers
