#!/usr/bin/env bash
# Network manager (click on the network pill): nmtui in a floating terminal,
# recoloured from newt's default magenta to the terminal's Latte palette.
# Latte flips the terminal palette: "black" is light grey and "lightgray"
# (terminal white) is the dark text colour, hence the odd-looking names.
export NEWT_COLORS='
root=lightgray,default
roottext=lightgray,default
helpline=lightgray,default
window=lightgray,default
border=blue,default
title=blue,default
label=lightgray,default
textbox=lightgray,default
entry=lightgray,default
disentry=gray,default
listbox=lightgray,default
sellistbox=blue,default
actlistbox=black,blue
actsellistbox=black,blue
checkbox=lightgray,default
actcheckbox=black,blue
button=black,blue
actbutton=black,magenta
compactbutton=lightgray,default
emptyscale=,default
fullscale=,blue
'
exec alacritty --class floating-term,floating-term -e nmtui
