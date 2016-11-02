# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# File: lab5.asm
# Authors: Sabrina Banh and Gerard Geer
# Purpose:
# 	Takes a string of letters, and returns its lowercase contents sorted
#	lexiographically. Uses Radix sort as an exercise to learn it, and also does
#	all memory work on the heap.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# STATIC DATA DEFINITIONS =====================================================
	.data
# No data yet.

# PROCEDURE DEFINITION ========================================================
	.text 
#------------------------------------------------------------------------------
# Function: main
# The entry point function into the program. Currently just tests stuff.
# Parameters:
#	None
# Returns:
#	None
#------------------------------------------------------------------------------
main:

	# Create 5 buckets of length 5 on the heap. This is just to test the
	# function. 
	li $a1, 5
	li $a2, 8
	jal create_buckets

	# Exit.
	li $v0, 10
	syscall

#------------------------------------------------------------------------------
# Function: get_binary_digit
# Returns the nth binary digit of a number. Does not modify values stored in
# parameters.
#
# Parameters:
#	a0: The number to retrieve a bit from.
#	a1: <n> The bit to retrieve, starting at 0.
#
# Returns:
#	v0: The digit.
#------------------------------------------------------------------------------
get_binary_digit:
	# Shift the value the correct number of bits into a new register
	# so we don't destroy the original.
	srlv $t0, $a0, $a1

	# Now we bitmask it with 0b0000.0000001 so we are left with only
	# the first bit. This gives us a return value of either 1 or zero,
	# which is what we need in order to choose a bucket.
	andi $v0, $t0, 1

	# Return.
	jr $ra

#------------------------------------------------------------------------------
# Function: create_buckets
# Creates <n> buckets of <m> size. Stores two atlases of their positions in
# memory: One for location purposes, and the other for incrementing to the
# next available position purposes.
#
# Parameters:
#	a1: <n> The number of buckets to create.
#	a2: <m> How many entries need to fit in each bucket,
#
# Returns:
#	v0: The first location table.
#	v1: The second location table.
#------------------------------------------------------------------------------
create_buckets:
	# Create the first of the two atlases.
	addi $v0, $zero, 9
	# Set the required size to enough bytes for a word-length pointer to
	# each bucket.
	mul $a0, $a1, 4
	# Perform the syscall that actually allocates the memory.
	syscall
	# Schindler's list the pointer into $t0 so we don't overwrite it.
	add $t0, $zero, $v0

	# Second atlas. Since $v0 was written to, we have to reload the value.
	addi $v0, $zero, 9 
	syscall	# We don't need to re-write to $a0
	add $t1, $zero, $v0	

	# Initialize a loop index counter.
	addi $t2, $t2, 0
	
	# Oh, and since each bucket is the same size, we can store the capacity
	# beforehand. Note we multiply it by four to go from number of words
	# to the number of bytes necessary to lodge those words.
	mul $a0, $a2, 4

	# A loop that allocates memory for each bucket, and places the pointer on
	# the stack.
	bucket_creation_loop:
		# Make sure we haven't created enough buckets yet.
		bge $t2, $a1, return_create_buckets
		# Tell the system to give us m*4 bytes of memory, and store a pointer
		# to it in $v0.
		addi $v0, $zero, 9
		syscall
		
		# Add the address to the atlases, and increment them.
		sw $v0, ($t0)
		sw $v0, ($t1)
		addi $t0, $t0, 4
		addi $t1, $t1, 4

		# Increment the counter.
		addi $t2, $t2, 1
	# On the next episode of Bucket Creation Loop, we do the same darn thing!
	# Oh did I say Bucket Creation Loop? I meant to say MGSV.
	j bucket_creation_loop

	return_create_buckets: # Fly out of the loop? You'll land here.
	# Now that the atlases are created, we need to return the pointers to
	# the start. Oh, and since we don't need $a2 anymore, we can just use
	# it.
	mul $a2, $a2, 4
	sub $v0, $t0, $a2 # Put these things into the return registers.
	sub $v1, $t1, $a2
	
	# Return.
	jr $ra

#------------------------------------------------------------------------------
# Function: insert_into_bucket
# Takes a value, a particular digit to consider from it, a pointer to an
# atlas of bucket pointers, and how many buckets there are. With this data
# this function inserts the value into the correct bucket.
# Parameters:
#	a0: A pointer to the read-write bucket atlas.
#	a1: How many buckets there are.
#	a2: The value to insert.
#	a3: The digit to insert in respect to.
# Returns:
#	None.
#------------------------------------------------------------------------------
insert_into_bucket:
	# First things first, we get the digit value. We have to stash the current
	# parameters and the return address to do this.
	addi $sp, $sp, -12
	sw $a0, 8($sp)
	sw $a1, 4($sp)
	sw $ra, 0($sp)

	# Now we need to prepare the arguments for get_binary_digit.
	add $a0, $zero, $a2	# The number to get the bit from.
	add $a1, $zero, $a3	# The bit to get.

	# Woo! Make the call. The digit will be in $v0. We need that register,
	# so we put the value in $t0.
	jal get_binary_digit
	add $t0, $zero, $v0

	# Restore what we pushed onto the stack.
	lw $a0, 8($sp)
	lw $a1, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 12
	

	# Multiply that digit by 4 to get an offset into the atlas.
	mul $t0, $t0, 4
	# Since we can't offset by a register value, we need to prepare
	# an address ourselves.
	add $t0, $t0, $a0
	# Get the address from the atlas.
	lw $t1, ($t0)
	# Store the value at that address.
	sw $a2, ($t1)
	# Increment the pointer to the bucket so it points to its next slot.
	addi $t1, $t1, 4	# Four bytes = one word.
	# Update the atlas with the new address.
	sw $t1, ($t0)

	# Finally we can get out of this function.
	jr $ra
	
	
	
	
