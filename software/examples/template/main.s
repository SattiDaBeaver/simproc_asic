.data
# data starts here (32 bytes max)
#
# format: <label> <value (signed 8 bit)>
# example: num 3

.text
# code starts here
# using labels: only works for "ori"
# example: ori num ==> ori 0 (replaces with address of num)