#!/bin/sh
#
# MKlib_gen.sh -- generate sources from curses.h macro definitions
#
# (Id: MKlib_gen.sh,v 1.9 1997/05/10 23:48:19 tom Exp $)
#
# The XSI Curses standard requires all curses entry points to exist as
# functions, even though many definitions would normally be shadowed
# by macros.  Rather than hand-hack all that code, we actually
# generate functions from the macros.
#
# This script accepts a file of prototypes on standard input.  It discards
# any that don't have a `generated' comment attached. It then parses each
# prototype (relying on the fact that none of the macros take function 
# pointer or array arguments) and generates C source from it.
#
# Here is what the pipeline stages are doing:
#
# 1. sed: extract prototypes of generated functions
# 2. sed: decorate prototypes with generated arguments a1. a2,...z
# 3. awk: generate the calls with args matching the formals 
# 4. sed: prefix function names in prototypes so the preprocessor won't expand
#         them.
# 5. cpp: macro-expand the file so the macro calls turn into C calls
# 6. awk: strip the expansion junk off the front and add the new header
# 7. sed: squeeze spaces, strip off gen_ prefix, create needed #undef
#

preprocessor="$1 -I../include"
AWK="$2"
TMP=gen$$.c
trap "rm -f $TMP" 0 1 2 5 15

(cat <<EOF
#include <ncurses_cfg.h>
#include <curses.h>

DECLARATIONS

EOF
sed -n -e "/^extern.*generated/s/^extern \([^;]*\);.*/\1/p" \
| sed \
	-e "/(void)/b nc" \
	-e "s/,/ a1% /" \
	-e "s/,/ a2% /" \
	-e "s/,/ a3% /" \
	-e "s/,/ a4% /" \
	-e "s/,/ a5% /" \
	-e "s/,/ a6% /" \
	-e "s/,/ a7% /" \
	-e "s/,/ a8% /" \
	-e "s/,/ a9% /" \
	-e "s/,/ a10% /" \
	-e "s/,/ a11% /" \
	-e "s/,/ a12% /" \
	-e "s/,/ a13% /" \
	-e "s/,/ a14% /" \
	-e "s/,/ a15% /" \
	-e "s/*/ * /g" \
	-e "s/%/ , /g" \
	-e "s/)/ z)/" \
	-e ":nc" \
	-e "/(/s// ( /" \
	-e "s/)/ )/" \
| $AWK '{
	print "\n"

	print "M_" $2
	print $0;
	print "{";
	argcount = 1;
	if (NF == 5 && $4 == "void")
		argcount = 0;
	if (argcount != 0) {
		for (i = 1; i <= NF; i++)
			if ($i == ",")
				argcount++;
	}

	# suppress trace-code for functions that we cannot do properly here,
	# since they return data.
	dotrace = 1;
	if ($2 == "innstr")
		dotrace = 0;

	call = "%%T((T_CALLED(\""
	args = ""
	comma = ""
	num = 0;
	pointer = 0;
	argtype = ""
	for (i = 1; i <= NF; i++) {
		ch = $i;
		if ( ch == "*" )
			pointer = 1;
		else if ( ch == "va_list" )
			pointer = 1;
		else if ( ch == "char" )
			argtype = "char";
		else if ( ch == "int" )
			argtype = "int";
		else if ( ch == "short" )
			argtype = "short";
		else if ( ch == "chtype" )
			argtype = "chtype";
		else if ( ch == "attr_t" || ch == "NCURSES_ATTR_T" )
			argtype = "attr";

		if ( ch == "," || ch == ")" ) {
			if (pointer) {
				if ( argtype == "char" ) {
					call = call "%s"
					comma = comma "_nc_visbuf2(" num ","
					pointer = 0;
				} else
					call = call "%p"
			} else if (argcount != 0) {
				if ( argtype == "int" || argtype == "short" ) {
					call = call "%d"
					argtype = ""
				} else if ( argtype != "" ) {
					call = call "%s"
					comma = comma "_trace" argtype "2(" num ","
				} else {
					call = call "%#lx"
					comma = comma "(long)"
				}
			}
			if (ch == ",")
				args = args comma "a" ++num;
			else if (argcount != 0)
				args = args comma "z"
			call = call ch
			if (pointer == 0 && argcount != 0 && argtype != "" )
				args = args ")"
			if (args != "")
				comma = ", "
			pointer = 0;
			argtype = ""
		}
		if ( i == 2 || ch == "(" )
			call = call ch
	}
	call = call "\")"
	if (args != "")
		call = call ", " args
	call = call ")); "

	if (dotrace)
		printf "%s", call

	if (match($0, "^void"))
		call = ""
	else if (dotrace)
		call = "returnCode( ";
	else
		call = "%%return ";

	call = call $2 "(";
	for (i = 1; i < argcount; i++)
		call = call "a" i ", ";
	if (argcount != 0)
		call = call "z";
	if (!match($0, "^void"))
		call = call ") ";
	if (dotrace)
		call = call ")";
	print call ";"

	if (match($0, "^void"))
		print "%%returnVoid;"
	print "}";
}
' ) \
| sed \
	-e '/^\([a-z_][a-z_]*\) /s//\1 gen_/' >$TMP
  $preprocessor $TMP 2>/dev/null \
| $AWK '
BEGIN		{
	print "/*"
	print " * DO NOT EDIT THIS FILE BY HAND!"
	print " * It is generated by MKlib_gen.sh."
	print " *"
	print " * This is a file of trivial functions generated from macro"
	print " * definitions in curses.h in order to satisfy the XSI Curses"
	print " * requirement that every macro also exist as a callable"
	print " * function."
	print " *"
	print " * It will never be linked unless you call one of the entry"
	print " * points with its normal macro definition disabled.  In that"
	print " * case, if you have no shared libraries, it will indirectly"
	print " * pull most of the rest of the library into your link image."
	print " * Cope with it."
	print " */"
	print "#include <curses.priv.h>"
	print ""
		}
/^DECLARATIONS/	{start = 1; next;}
		{if (start) print $0;}
' \
| sed \
	-e 's/		*/ /g' \
	-e 's/  */ /g' \
	-e 's/ ,/,/g' \
	-e 's/ )/)/g' \
	-e 's/ gen_/ /' \
	-e 's/^M_/#undef /' \
	-e '/^%%/s//	/' \
| sed \
	-e 's/^.*T_CALLED.*returnCode( \([a-z].*) \));/	return \1;/' \
	-e 's/^.*T_CALLED.*returnCode( \((wmove.*) \));/	return \1;/'

