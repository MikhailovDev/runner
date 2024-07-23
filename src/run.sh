#!/bin/bash

CLANG_FORMAT="clang-format"
CPPCHECK="cppcheck"
GCC="gcc"
MEMORY_TOOL="valgrind"

SOURCE_DIR="${HOME}/bin/run"
BIN="${HOME}/bin"
CURRENT_DIR="$(pwd)"

CLANG_FORMAT_FP=${SOURCE_DIR}/".clang-format"
USER_DATA_FP=${SOURCE_DIR}/".run_opts"
DFLT_DATA_FP=${SOURCE_DIR}/".run_default"
CORRECT_DATA_FP=${SOURCE_DIR}/".run_opts_correct"

BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"
USER_DFLTRC="${HOME}/.$( basename $( echo $SHELL ) )rc"
USER_CURRENTRC="${HOME}/.$( ps -cp "$$" -o command="" )rc"

OFF_SIGN="OFF>>>"

declare -A cmd_opts

declare -a cmds=(
	$CLANG_FORMAT
	$CPPCHECK
	$GCC
	$MEMORY_TOOL
)

is_key_exists() { local -n arr_ref=$1; [[ " ${!arr_ref[@]} " =~ " $2 " ]] && return 0 || return 1; }
is_item_exists() { local -n arr=$1; [[ " ${arr[@]} " =~ " $2 " ]] && return 0 || return 1; }

split() {
    while read -r word; do
        echo -n "$word"
    done <<< "$1"
}

print_arr_to_column() { local -n arr=$1; echo "${arr[@]}" | sed "s/ /\n/g"; }

load_user_data() {
    while IFS=$': \n\t' read -r command options; do
		if [[ "$command" != *"$OFF_SIGN"* ]]; then
        	cmd_opts[$command]+=${options}
		fi
    done < $USER_DATA_FP
}

run_message() {
	echo "run: $1"
}

get_user_answer() {
	read -n1 -s -p "$(run_message "$1")" answer
	echo
	if [[ "${answer,,}" == 'n' || "${answer,,}" != 'y' ]]; then
		return 1
	else
		return 0
	fi
}

open_in_editor() {
	if [[ -n $EDITOR ]]; then
		"$EDITOR" "$1"
	else
		vim "$1"
	fi
}

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

if ! is_cmd_exists $GCC; then install_cmd $GCC; fi
if ! is_cmd_exists $CPPCHECK; then install_cmd $CPPCHECK; fi
if ! is_cmd_exists $CLANG_FORMAT; then install_cmd $CLANG_FORMAT; fi
if ! is_cmd_exists $MEMORY_TOOL; then install_cmd $MEMORY_TOOL; fi

is_key_exists() { local -n arr_ref=$1; [[ " ${!arr_ref[@]} " =~ " $2 " ]] && return 0 || return 1; }
is_item_exists() { local -n arr=$1; [[ " ${arr[@]} " =~ " $2 " ]] && return 0 || return 1; }

split_file_into_lines() {
	local -n list=$2

	# IFS sets word separators to '\n' char - means that one word
	# should consisits of one line;
	# -d (--delimeter) sets to '' which means that read should
	# write until EOF.
	# -a set the output into array.
	IFS=$'\n' read -d '' -a list < $1
}

rm_lines_with_disabled_cmds() {
	local -n lines=$1
	declare -a enabled

	for i in ${!lines[@]}; do
		if [[ "${lines[i]}" != *"$OFF_SIGN"* ]]; then
			enabled+=($i)
		fi
	done
	for i in ${!enabled[@]}; do
		idx=${enabled[$i]}
		lines[$i]=${lines[$idx]}
	done

	lines=( "${lines[@]:0:${#enabled[@]}}" )
}

option_cl_clang_format() {
	filepath="$1"
	file=${filepath##*/}
	user_filepath="${CURRENT_DIR}/${filepath}"
	# echo "us fp: $user_filepath"
	# echo "fp: $filepath"
	# echo "file: $file"
	if [[ -z "$filepath" ]]; then
		run_message "You need to specify the path for your '.clang-format' file."
		exit 1
	elif ! [[ -e $user_filepath ]]; then
		run_message "No such file: $filepath"
		exit 1
	elif [[ "$file" != ".clang-format" ]]; then
		run_message "You need to specify the '.clang-format' file instead of '$file'"
		exit 1
	else
		cat $user_filepath > .$CLANG_FORMAT
		exit 0
	fi
}

is_r_a_options_input_correct() {
	if [[ -z "$1" ]]; then
		run_message "You need to specify the command."
		run_message "Available commands: "
		print_arr_to_column cmds
		return 1
	elif ! is_item_exists cmds $1; then
		run_message "No such command: $1"
		run_message "Available commands: "
		print_arr_to_column cmds
		return 1
	fi

	return 0
}

option_r_remove() {
	cmd_name="$1"
	if ! is_r_a_options_input_correct "$cmd_name"; then
	 	exit 1
	fi

	load_user_data

	split_file_into_lines $USER_DATA_FP lines
	for i in ${!lines[@]}; do
		command=$(awk '{print $1}' <<< ${lines[$i]} | sed 's/:$//')
		if [[ "$command" != "$cmd_name" ]]; then
			if [[ "$command" == *"$cmd_name"* ]]; then
				run_message "Command '$cmd_name' is already disabled."
				exit 0
			else
				continue
			fi
		fi

		# echo "command '$command' disabled"
		sed -i "$((i+1))s/^/$OFF_SIGN/" $USER_DATA_FP
		sed -i "$((i+1))s/^/$OFF_SIGN/" $CORRECT_DATA_FP
		break
	done

	run_message "The command '$cmd_name' is now disabled."
	exit 0
}

option_a_add() {
	cmd_name="$1"
	if ! is_r_a_options_input_correct $cmd_name; then
		exit 1
	fi

	split_file_into_lines $USER_DATA_FP lines

	for i in ${!lines[@]}; do
		command=$(awk '{print $1}' <<< ${lines[$i]} | sed 's/:$//')
		if [[ "$command" == "$cmd_name" ]]; then
			run_message "Command '$cmd_name' is already enabled."
			exit 0
		elif [[ "$command" == *"$cmd_name"* ]]; then
			sed -i "$((i+1))s/^$OFF_SIGN//" $USER_DATA_FP
			sed -i "$((i+1))s/^$OFF_SIGN//" $CORRECT_DATA_FP
			run_message "The command '$cmd_name' is now enabled."
			exit 0
		else
			continue
		fi
	done
}

arg="$1"
if [[ "${arg:0:1}" == "-" ]]; then
	arg_optn=${arg%=*}
	[[ "$arg" == *"="* ]] && arg_val=${arg#*=} || arg_val=""

	case "$arg_optn" in
		-v | --view-options)
			prev_permissions=$(stat -c %a $USER_DATA_FP)
			chmod 444 $USER_DATA_FP

			open_in_editor $USER_DATA_FP

			chmod $prev_permissions $USER_DATA_FP
			exit 0
		;;
		-c | --change-options)
			# echo "Before: ${!cmd_opts[@]}"
			load_user_data
			# echo "After: ${!cmd_opts[@]}"

			open_in_editor $USER_DATA_FP

			declare -a old_lines
			declare -a new_lines
			split_file_into_lines $CORRECT_DATA_FP old_lines
			split_file_into_lines $USER_DATA_FP new_lines
			rm_lines_with_disabled_cmds old_lines
			rm_lines_with_disabled_cmds new_lines

			for ((i = 0; i < ${#cmd_opts[@]}; i++)); do
			  	if ! is_key_exists cmd_opts $(awk '{print $1}' <<< ${new_lines[$i]} | sed 's/:$//'); then
				 	# echo $(awk '{print $1}' <<< ${new_lines[$i]} | sed 's/:$//')
					run_message "You can't remove or rename commands."
					cat $CORRECT_DATA_FP > $USER_DATA_FP
					run_message "Last version restored."
					exit 1
				fi
			done
			unset i

			if [[ $(wc -l < $USER_DATA_FP) -ne ${#cmds[@]} ]]; then
				run_message "You can't add another lines."
				cat $CORRECT_DATA_FP > $USER_DATA_FP
				run_message "Last version restored."
				exit 1
			fi
			# echo "Old lines: ${old_lines[@]}"
			# echo "New lines: ${new_lines[@]}"
			for i in ${!old_lines[@]}; do
				IFS=$': ' read -a old_words <<< "${old_lines[$i]}"
				IFS=$': ' read -a new_words <<< "${new_lines[$i]}"

				# echo "Old words: ${old_words[@]}"
				# echo "New words: ${new_words[@]}"
				declare -a added_words
				for new_option in ${new_words[@]:1}; do
					if [[ ! " ${old_words[@]} " =~ " $new_option " ]]; then
						added_words+=("$new_option")
					fi
				done
				cmd_opts[${new_words[0]}]="${added_words[*]}"
				unset added_words
			done

			# for command in "${!cmd_opts[@]}"; do
			# 	echo "$command: ${cmd_opts[$command]}"
			# done

			for command in "${!cmd_opts[@]}"; do
			 	# echo "Command: ${command}"
				read -ra options <<< "${cmd_opts[$command]}"
				for option in ${options[@]}; do
					option_name=${option%=*}
					# echo "Option: $option"
					# echo "Option name: $option_name"
					if [[ ${option_name:0:1} != '-' ]]; then
						continue
					fi

					if ! man "$command" 2>/dev/null | grep -e "$option_name" &>/dev/null ; then
						run_message "Option '$option_name' wasn't found in the '$command' command."

						if get_user_answer "Restore the latest version with the correct options? [Y/n] "; then
							cat $CORRECT_DATA_FP > $USER_DATA_FP
							run_message "Options restored."
							exit 0
						fi

						exit 1
					fi
				done
			done
			run_message "Options succesfully updated."
			cat $USER_DATA_FP > $CORRECT_DATA_FP
			exit 0
		;;
		-r)
			option_r_remove $2
		;;
		--remove)
			option_r_remove "$arg_val"
		;;
		-a)
			option_a_add $2
		;;
		--add)
			option_a_add $"$arg_val"
		;;
		-cl)
			option_cl_clang_format "$2"
		;;
		--clang-format)
		 	option_cl_clang_format "$arg_val"
		;;
		-d | --default)
			cat $DFLT_DATA_FP > $USER_DATA_FP
			cat $DFLT_DATA_FP > $CORRECT_DATA_FP
			run_message "Default options restored."
			exit 0
		;;
		-u | --uninstall)
			if ! get_user_answer "Are you sure you want to uninstall 'run' command? [Y/n] "; then
				exit 0
			fi

			rm -rf "$SOURCE_DIR"

			# Checks the $BIN dir for emptiness.
			if [ ! -n "$(ls -A "$BIN" 2>/dev/null)" ]; then
				rm -rf "$BIN"
			fi

			if [[ -e "$BASHRC" && "$BASHRC" != "$USER_CURRENTRC" ]]; then
				sed -i "/^alias run=/d" "$BASHRC"
			fi

			if [[ -e "$ZSHRC" && "$ZSHRC" != "$USER_CURRENTRC" ]]; then
				sed -i "/^alias run=/d" "$ZSHRC"
			fi

			if [[ -e "$USER_DFLTRC" && "$USER_DFLTRC" != "$USER_CURRENTRC" ]]; then
				sed -i "/^alias run=/d" "$USER_DFLTRC"
			fi

			sed -i "/^alias run=/d" "$USER_CURRENTRC"
			. "$USER_CURRENTRC"

			run_message "Command uninstalled."
			exit 0
		;;
		-h | --help)
			echo "Usage: run FILE

Compiles a file written in C, runs the clang-format, valgrind and cppcheck commands with their predefined options, and executes the compiled program until you stop it.

These commands:
- clang-format;
- gcc;
- cppcheck;
- valgrind;
use predefined options that you can edit by calling 'run -c' or 'run --change-options', or you can also restore the default options.

In addition, you can stop the execution of some commands.

Options:
-u, --uninstall
	Deletes the 'run' command.

-c, --change-options
	Opens a file with the user defined options of the above commands in order to change them.
	Note, that you cannot delete, rename commands or add other lines - you can only add or remove options following a colon and separated by a space.

-v, --view-options
	Shows a user defined options for commands in read-only mode.

-d, --default
	Restores the original command options that were set by default.

-cl, --clang-format=YOUR-CLANG-FORMAT-FILE
	Updates the current '.clang-format' file to the specified 'YOUR-CLANG-FORMAT-FILE'.

-r, --remove=COMMAND-NAME
	Stops the execution of the command. 'COMMAND-NAME' will no longer be executed when running 'run' until you resume it using the '-a' option.

-a, --add=COMMAND-NAME
	Resumes the work of the stopped command. 'COMMAND-NAME' continues to work with the options that were specified before it was stopped.

-h, --help
	Shows brief information on using the 'run' command.

Documentation: https://github.com/MikhailovDev/runner/blob/main/README.md
"
exit 0
		;;
		*)
			run_message "No such option: $1"
			exit 1
		;;
	esac
fi

FILEPATH="$1"
FILE=$(basename "$1")
FILENAME=${FILE%.*}
FILE_EXTENSION=.${FILE##*.}
OUTPUT_FILE=${FILENAME}.out

if [[ $# -eq 0 ]]; then
	run_message "You need to specify the file."
	exit 1
fi

if [[ ! -e "$FILEPATH" ]]; then
	run_message "There is no file named '$FILE'"
	exit 1
fi

load_user_data

LOG_FOLDER="log"
if [[ ! -d $LOG_FOLDER ]]; then
	mkdir $LOG_FOLDER
fi

# for command in "${!cmd_opts[@]}"; do
	# echo "$command: ${cmd_opts[$command]}"
# done
# FILEPATH in double quotes to handle cases where the file path
# contains spaces or special characters

if is_key_exists cmd_opts $CLANG_FORMAT; then
	# echo "$CLANG_FORMAT works"
	CLANG_FORMAT_ERROR_FILE=${LOG_FOLDER}/clang-format_error.log
	cp "$CLANG_FORMAT_FP" "$CURRENT_DIR"
	if ! clang-format $(split "${cmd_opts[$CLANG_FORMAT]}") "$FILEPATH" 1> /dev/null 2> "$CLANG_FORMAT_ERROR_FILE"; then
		open_in_editor "$CLANG_FORMAT_ERROR_FILE"
		rm "$CURRENT_DIR"/.$CLANG_FORMAT
		exit 1
	fi
	rm "$CURRENT_DIR"/.$CLANG_FORMAT
fi


if is_key_exists cmd_opts $CPPCHECK; then
	# echo "$CPPCHECK works"
	CPPCHECK_ERROR_FILE=${LOG_FOLDER}/cppcheck_error.log
	if ! cppcheck $(split "${cmd_opts[$CPPCHECK]}") "$FILEPATH" 1> /dev/null 2> "$CPPCHECK_ERROR_FILE"; then
		open_in_editor "$CPPCHECK_ERROR_FILE"
		exit 1
	fi
fi

if is_key_exists cmd_opts $GCC; then
	# echo "$GCC works"
	GCC_ERROR_FILE=${LOG_FOLDER}/gcc_error.log
	if ! gcc "$FILEPATH" $(split "${cmd_opts[$GCC]}") -o "$OUTPUT_FILE" 1> /dev/null 2> "$GCC_ERROR_FILE"; then
		open_in_editor "$GCC_ERROR_FILE"
		exit 1
	fi
fi

if is_key_exists cmd_opts $MEMORY_TOOL; then
	# echo "$MEMORY_TOOL works"
	MEM_TOOL_ERROR_FILE=${LOG_FOLDER}/memory_tool_error.log
	if ! valgrind $(split "${cmd_opts[$MEMORY_TOOL]}") ./"$OUTPUT_FILE" < /dev/null 1> /dev/null 2> "$MEM_TOOL_ERROR_FILE"; then
		open_in_editor "$MEM_TOOL_ERROR_FILE"
		exit 1
	fi
fi

while
    ./$OUTPUT_FILE "${@:2}"
    echo
    run_message "Press 'Enter' to continue or 'Esc' to quit."

    # - The -n1 flag tells read to read only one character at a time.
    # - The -r flag prevents backslashes from being interpreted.
    # - The -s flag makes the input silent (not echoed to the terminal).
    # - The -p flag is used to display the prompt ${PS1} ~ run$  without a newline
    # character.

    read -n1 -r -s -p "run > " char
    if [[ "$char" == $'\e' ]]; then
        break
    else
        echo
    fi
do true; done

if [[ -f "$OUTPUT_FILE" ]]; then
	rm  "$OUTPUT_FILE"
fi
rm -rf ${LOG_FOLDER}

exit 0
