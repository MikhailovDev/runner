#!/bin/bash

DIR="${HOME}/bin/run"
CURRENT_DIR="$(pwd)"

BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"
USER_DFLTRC="${HOME}/.$( basename $( echo $SHELL ) )rc"
USER_CURRENTRC="${HOME}/.$( ps -cp "$$" -o command="" )rc"

run_message() {
	echo "run: $1"
}

if [[ -d "$DIR" ]]; then
	run_message "Reinstallation..."
	run -u &> /dev/null <<< 'y'
fi

is_cmd_exists() {
	if [ -x "$(command -v "$1")" ]; then
		return 0
	else
		return 1
	fi
}

install_cmd() {
	sudo apt-get update
	sudo apt-get install "$1"
}

if ! is_cmd_exists git; then install_cmd git; fi

mkdir -p "$DIR"
cd "$DIR"

if [[ -e "$BASHRC" && "$BASHRC" != "$USER_CURRENTRC" ]]; then
	echo "alias run=\"$DIR/run.sh\"" >> "$BASHRC"
fi

if [[ -e "$ZSHRC" && "$ZSHRC" != "$USER_CURRENTRC" ]]; then
	echo "alias run=\"$DIR/run.sh\"" >> "$ZSHRC"
fi

if [[ -e "$USER_DFLTRC" && "$USER_DFLTRC" != "$USER_CURRENTRC" ]]; then
	echo "alias run=\"$DIR/run.sh\"" >> "$USER_DFLTRC"
fi

echo "alias run=\"$DIR/run.sh\"" >> "$USER_CURRENTRC"
. "$USER_CURRENTRC"

git init
git remote add -f origin https://github.com/MikhailovDev/runner
git config core.sparseCheckout true
echo "/src" >> .git/info/sparse-checkout
git pull origin main-verbose

for file in $(find $DIR/src -type f); do
	mv $(realpath "$file") "$DIR"
done
rm -rf src .git

chmod 755 "${DIR}/run.sh"
chmod 766 "${DIR}/.run_opts"
chmod 744 "${DIR}/.run_default"
chmod 744 "${DIR}/.run_opts_correct"

filepath="$1"
file=${filepath##*/}
user_filepath="${CURRENT_DIR}/${filepath}"
if [[ -z "$filepath" ]]; then
	exit 0
else
	if ! run -cl "$filepath"; then
		run_message "The predefined file is now used."
		run_message "To change it, write 'run -cl path/to/your/.clang-format'."
	fi
fi

exit 0
