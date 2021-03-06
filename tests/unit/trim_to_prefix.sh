#!/bin/sh
# This file is licensed under the BSD-3-Clause license.
# See the AUTHORS and LICENSE files for more information.

. ../spec_helper.sh
. ../../share/zfsnap/core.sh

# These include a date pattern, and should be trimmed accordingly
PREFIXES=''
ItsRetvalIs "TrimToPrefix '2011-04-05_02.06.00--1y'"               ""         0 # w/o prefix

PREFIXES='daily-- hourly-'
ItsRetvalIs "TrimToPrefix 'hourly-2011-04-05_02.06.00--1y'"        "hourly-"  0 # prefix
ItsRetvalIs "TrimToPrefix 'daily--2011-04-05_02.06.00--1y'"        "daily--"  0 # prefix using TTL delim

PREFIXES='wtf- 2004-04-05_23.32.00--'
ItsRetvalIs "TrimToPrefix '2004-04-05_23.32.00--2008-01-05_23.32.00--1y'"  "2004-04-05_23.32.00--"  0  # an idiot/asshole uses a date in the prefix

PREFIXES='wtf--1y- wtf--6M-'
ItsRetvalIs "TrimToPrefix 'wtf--6M-2008-01-05_23.32.00--1y'"       "wtf--6M-" 0  # an idiot/asshat uses TTL w/ delim in the prefix

# These don't contain a date pattern, and should return an empty string
PREFIXES=''
ItsRetvalIs "TrimToPrefix 'hourly-2011-04-05_02.06.00--1y'"        ""         1 # invalid prefix

PREFIXES='daily-- hourly-'
ItsRetvalIs "TrimToPrefix ''"                                      ""         1 # empty
ItsRetvalIs "TrimToPrefix 'weekly-2011-04-05_02.06.00--1y'"        ""         1 # invalid prefix
ItsRetvalIs "TrimToPrefix '2011-04-05_02.06.00--1y'"               ""         1 # invalid (empty) prefix
ItsRetvalIs "TrimToPrefix 'zpool/child/grandchild'"                ""         1 # pool/fs
ItsRetvalIs "TrimToPrefix 'zpool@yesterday'"                       ""         1 # full snapshot, w/ no prefix or date
ItsRetvalIs "TrimToPrefix 'zpool@weekly--1y3w'"                    ""         1 # full snapshot, w/ supposed "prefix" and TTL, but no date

ExitTests
