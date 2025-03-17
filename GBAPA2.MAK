# Make the GBAPA2 demo with TASM.
# This makefile assumes, that TASM is renamed to GASM, and TASM69.TAB is
# renamed to TASMGB.TAB

# Rule for making a single-bank image 
.asm.gbs:
	gasm -tGB -b -s -c $*.asm
	sym2l $*.sym $*.l
	calc_crc $*.obj $*.gbs
	del $*.obj
	del $*.sym
#	del $*.lst

# Project:
gbapa2.gbs: gbapa2.asm
