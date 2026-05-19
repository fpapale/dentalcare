cd ~/docker/dentalcarepro
[ -f install.sh ] && rm install.sh
git pull origin master
bash install.sh --update
