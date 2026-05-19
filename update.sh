cd ~/docker/dentalcarepro
[ -f install.sh ] && rm install.sh
[ -f update.sh ] && rm update.sh
git pull origin master
bash install.sh --update
