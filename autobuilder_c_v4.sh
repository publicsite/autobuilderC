#!/bin/sh

compileObjectFile(){
	outDir="${1}"
	objectfile="${2}"
	CC="${3}"
	CFLAGS="${4}"
	LDFLAGS="${5}"


		X=0
		while true; do

			if [ -d "${outDir}/library_${X}" ]; then
				#compile and link against .o files
echo "${CC} -c "$file" ${CFLAGS} ${LDFLAGS} -L "${outDir}/library_${X}" -l "${outDir}/library_${X}/library_${X}" -o "${outDir}/library_${X}/${objectfile}.o""
				${CC} -c "$file" ${CFLAGS} ${LDFLAGS} -L "${outDir}/library_${X}" -l "${outDir}/library_${X}/library_${X}" -o "${outDir}/library_${X}/${objectfile}.o"
				if [ "$?" = "0" ]; then
					#successful compile: try to link
echo "g++ -shared -fPIC -o "${outDir}/library_${X}/library_${X}.so" "${outDir}/library_${X}/"*".o""
					g++ -shared -fPIC -o "${outDir}/library_${X}/library_${X}.so.good" "${outDir}/library_${X}/"*".o" 2>&1
					if [ "$?" = "0" ]; then
						if [ -f "${outDir}/library_${X}/library_${X}.so.good" ]; then
							mv "${outDir}/library_${X}/library_${X}.so.good" "${outDir}/library_${X}/library_${X}.so"
						fi
						#successful compile and link: exit loop
						break;
					else
						if [ -f "${outDir}/library_${X}/${objectfile}.o" ]; then 
							rm "${outDir}/library_${X}/${objectfile}.o"
						fi
					fi
				elif [ -f "${outDir}/library_${X}/${objectfile}.o" ]; then 
					rm "${outDir}/library_${X}/${objectfile}.o"
				fi
			else

				if [ ! -d "${outDir}/staging" ]; then
					mkdir "${outDir}/staging"
				else
					if [ "$(find "${outDir}/staging/" -type f)" != "" ]; then
						rm "${outDir}/staging/"*
					fi
				fi

echo "${CC} -c "$file" ${CFLAGS} ${LDFLAGS} -o "${outDir}/staging/${objectfile}.o""
				${CC} -c "$file" ${CFLAGS} ${LDFLAGS} -o "${outDir}/staging/${objectfile}.o"
				if [ "$?" = "0" ]; then
					#successful compile: try to link
echo "g++ -shared -fPIC -o "${outDir}/staging/library_${X}.so" "${outDir}/staging/"*".o""
					g++ -shared -fPIC -o "${outDir}/staging/library_${X}.so.good" "${outDir}/staging/"*".o" 2>&1
					if [ "$?" != "0" ]; then
						if [ -f "${outDir}/staging/${objectfile}.o" ]; then 
							rm "${outDir}/staging/${objectfile}.o"
						fi
					else
						mv "${outDir}/staging/library_${X}.so.good" "${outDir}/staging/library_${X}.so"
						mv "${outDir}/staging" "${outDir}/library_${X}"
					fi
				else
					if [ -f "${outDir}/staging/${objectfile}.o" ]; then 
						rm "${outDir}/staging/${objectfile}.o"
					fi
				fi

				break
			fi

			X="$(expr $X + 1)"
		done
}

compileObjectFileWrapper(){
	outDir="${1}"
	objectfile="${2}"

	if [ "$(find "${outDir}" -maxdepth 1 -type d -name "library_*")" != "" ]; then
		if [ "$(find "${outDir}/library_"* -name "${objectfile}.o")" = "" ]; then
			compileObjectFile "${outDir}" "${objectfile}" "$3" "$4" "$5"
		fi
	else
		compileObjectFile "${outDir}" "${objectfile}" "$3" "$4" "$5"
	fi
}

compileProgramFile(){
	outDir="${1}"
	objectfile="${2}"
	CC="${3}"
	CFLAGS="${4}"
	LDFLAGS="${5}"
	file="${6}"
	filetype="${7}"

		X=0
		while true; do
			if [ -d "${outDir}/library_${X}" ]; then
				if [ ! -d "${outDir}/program_${X}" ]; then
					mkdir "${outDir}/program_${X}"
				fi

				result=1
				if [ "${filetype}" = "c" ]; then
					#echo "${CC} "$file" ${CFLAGS} ${LDFLAGS} "${outDir}/library_${X}" -L "library_${X}.so" -o "${outDir}/program_${X}/${objectfile}""
					${CC} "$file" ${CFLAGS} ${LDFLAGS} -L "${outDir}/library_${X}" -L "library_${X}.so" -o "${outDir}/program_${X}/${objectfile}"
					result="$?"
				elif [ "${filetype}" = "cpp" ]; then
					#echo "${CXX} "$file" ${CFLAGS} ${LDFLAGS} "${outDir}/library_${X}" -L "library_${X}.so" -o "${outDir}/program_${X}/${objectfile}""
					${CXX} "$file" ${CFLAGS} ${LDFLAGS} "${outDir}/library_${X}" -L "library_${X}.so" -o "${outDir}/program_${X}/${objectfile}"
					result="$?"
				fi

				if [ "$result" = "0" ]; then
					break
				fi
			else
				#try treating it as an object file instead of a program if it doesn't compile as a program
				compileObjectFileWrapper "${outDir}" "${objectfile}" "${CC}" "${CFLAGS}" "${LDFLAGS}"
				break
			fi
			X="$(expr $X + 1)"
		done
}

foreachcfile(){
export outDir="$2"
	grep -o "^#include[[:space:]]\".*\"" "$1" | while read header; do
		header="$(printf "%s" "$header" | cut -d "\"" -f 2 | cut -d "\"" -f 1)"
		printf "#include <%s>\n" "${header}" | cpp -H -o /dev/null 2>/dev/null
		if [ "$?" != "0" ]; then
			found=0
			for flag in $CFLAGS; do
				if [  "$(echo $flag | cut -c 1-2)" = "-I" ]; then
					thedir="$(echo $flag | cut -c 3-)"
						if [ -f "$thedir/${header}" ]; then
							found=1
							break
						fi
				fi
			done
			if [ "$found" = "0" ]; then
				find "${PWD}" -wholename "*${header}" | head -n 1 | while read header2; do
					if [ "${header2}" != "" ]; then
						if [ -f "${header2}" ]; then

							if [ "$(grep "^${header2}$" "${outDir}/.headers" )" = "" ]; then
								##echo "${header2}"
								echo "${header2}" >> "${outDir}/.headers"
								foreachcfile "${header2}" "${outDir}"
							fi
			
						fi
					fi
				done
			fi
		fi
	done

	grep -o "^#include[[:space:]]<.*>" "$1" | while read header; do
		header="$(printf "%s" "$header" | cut -d "<" -f 2 | cut -d ">" -f 1)"
		printf "#include <%s>\n" "${header}" | cpp -H -o /dev/null 2>/dev/null
		if [ "$?" != "0" ]; then
			found=0
			for flag in $CFLAGS; do
				if [  "$(echo $flag | cut -c 1-2)" = "-I" ]; then
					thedir="$(echo $flag | cut -c 3-)"
						if [ -f "$thedir/${header}" ]; then
							found=1
							break
						fi
				fi
			done
			if [ "$found" = "0" ]; then
				find "${PWD}" -wholename "*${header}" | head -n 1 | while read header2; do
					if [ "${header2}" != "" ]; then
						if [ -f "${header2}" ]; then
						
							if [ "$(grep "^${header2}$" "${outDir}/.headers" )" = "" ]; then
								##echo "${header2}"
								echo "${header2}" >> "${outDir}/.headers"
								foreachcfile "${header2}" "${outDir}"
							fi
			
						fi
					fi
				done
			fi
		fi
	done
}

if [ "${CC}" = "" ]; then
CC="gcc"
fi

if [ "${CXX}" = "" ]; then
CXX="g++"
fi

outDir="$PWD/out"

mkdir "${outDir}"

newval="0"

if [ ! -f Makefile ] && [ ! -f makefile ]; then
	if [ ! -f configure ]; then
		if [ ! -f autogen.sh ]; then
			if [ -f configure.in ]; then
				autoconf -f -i
			fi
		else
			./autogen.sh
		fi
	fi

	if [ -f configure ]; then
		./configure
	fi
fi

#if [ -f makefile ] || [ -f Makefile] ; then
#	make
#else

export old_CPATH="${CPATH}"


themainfunction(){
mainOrLibrary="$1"
old_CPATH="$2"
CC="$3"
CXX="$4"
outDir="$5"
newval="$6"

	while true; do

		oldval="$newval"

		if [ "$(find "${outDir}" -maxdepth 1 -type d -name "library_*")" = "" ]; then
			newval=0
		else
			if [ "$(find "${outDir}" -type d -name "program_*")" != "" ]; then
				newval="$(expr $(find "${outDir}/library_"* -type f | wc -l) + $(find "${outDir}/program_"* -type f | wc -l))"
			else
				newval="$(expr $(find "${outDir}/library_"* -type f | wc -l))"
			fi
		fi

		if [ "${oldval}" != "0" ]; then
			if [ "${newval}" -le "${oldval}" ]; then
				break
			fi
		fi

		index=0


		find "${PWD}" -wholename "*.c" -o -wholename "*.cpp" | while read file; do

			filetype=""

			objectfile="$(basename "$file")"
			if [ "$(echo $objectfile | grep "\.cpp$")" != "" ]; then
				filetype="cpp"
				objectfile="${objectfile%????}"
			else
				filetype="c"
				objectfile="${objectfile%??}"
			fi

			filehasmainfunction="$(cat "$file" | grep -vE "^\s{0,}/\*" | grep -vE "^\s{0,}\*" | grep -vE "^\s{0,}//" | tr "\n" " " | grep -E "\s{1,}main\s{0,}\(.*\)")"

			check="$(find "${outDir}" -type d -name "program_*")"
			if [ "$check" != "" ]; then
				check="$(find "${outDir}/program_"* -type f -name "${objectfile}")"
			fi

			if ( [ "$filehasmainfunction" = "" ] ) || ( [ "${check}" = "" ] && [ "$filehasmainfunction" != "" ] ); then

				if [ -f "${outDir}/.headers" ]; then
					rm "${outDir}/.headers"
				fi
				touch "${outDir}/.headers"

				export CPATH="${old_CPATH}"

				foreachcfile "$file" "${outDir}"

				old_ifs="$IFS"
IFS="
"
				for aheader in $(cat "${outDir}/.headers"); do
					if [ "$(echo "${CPATH}" | grep ":$(dirname "${aheader}")" )" = "" ]; then
						if [ "${CPATH}" = "" ]; then
							export CPATH="$(dirname "${aheader}")"
						else
							export CPATH=""${CPATH}":$(dirname "${aheader}")"
						fi
					fi
				done

IFS="$old_ifs"

				if [ "$filehasmainfunction" = "" ] && [ "${mainOrLibrary}" = "library" ]; then
					compileObjectFileWrapper "${outDir}" "${objectfile}" "${CC}" "${CFLAGS}" "${LDFLAGS}"
				elif [ -d "${outDir}/program_0" ] && [ "${mainOrLibrary}" = "main" ]; then
					if [ "$(find "${outDir}/program_"* -type f -name "${objectfile}")" = "" ]; then
						compileProgramFile "${outDir}" "${objectfile}" "${CC}" "${CFLAGS}" "${LDFLAGS}" "${file}" "${filetype}"					
					fi
				elif [ "${mainOrLibrary}" = "main" ]; then
						compileProgramFile "${outDir}" "${objectfile}" "${CC}" "${CFLAGS}" "${LDFLAGS}" "${file}" "${filetype}"					
				fi
			else
				echo "Skipping already compiled $file"
			fi

		done

		if [ "$(find "${outDir}" -type d -name "program_*" | wc -l)" != 0 ]; then
			if [ "$(expr $(find "${outDir}/library_"* -type f | wc -l) + $(find "${outDir}/program_"* -type f | wc -l))" = "$newval" ]; then
				break
			fi
		else
			if [ "$(expr $(find "${outDir}/library_"* -type f | wc -l))" = "$newval" ]; then
				break
			fi
		fi
	done
}


echo "===COMPILING LIBRARIES==="
themainfunction "library" "${old_CPATH}" "${CC}" "${CXX}" "${outDir}" "${newval}"

echo "===COMPILING PROGRAM(S)==="
themainfunction "main" "${old_CPATH}" "${CC}" "${CXX}" "${outDir}" "0"

#clean up
if [ -d "${outDir}/staging" ]; then
	rmdir "${outDir}/staging"
fi
if [ -f "${outDir}/.headers" ]; then
	rm "${outDir}/.headers"
fi

#delete empty program dirs
find "${outDir}" -maxdepth 1 -type d -name "program_*" | while read line; do
	if [ "$(find "$line" -type f)" = "" ]; then
		rmdir "$line"
	fi
done