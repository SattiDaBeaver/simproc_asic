.data
# data starts here (32 bytes max)
#
# format: <label> <value (signed 8 bit)>
# example: num 3
VAL 15

.text
# code starts here
# using labels: only works for "ori"
# example: ori num ==> ori 0 (replaces with address of num)

sub r0, r0
ori VAL
load r1, r0 # load value of VAL into r1 or r1 <== [r0]

jump 1
jump -5

sub r2, r2
add r2, r0 # equivalent to r2 <== r0

sub r0, r0
ori 1 # r0 <== 0

add r1, r0 # r1 <== r1 + 1
store r2, r1 # [r0] <== r1

jump -8
