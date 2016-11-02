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
stored_at: .asciiz " stored at: "

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
	# Tests get binary digit, by getting bit 2 (third digit) of 6.
	# This should print out 1.
	li $a0, 6				# Load 6.
	li $a1, 2				# Hey get the second digit.
	jal get_binary_digit	# Do the function call.
	add $a0, $zero, $v0		# Move the output of the func into the arg.
	li $v0, 1				# Tell the system we're printing an int.
	syscall					# Actually perform the syscall.
	li $a0, ' '				# This just prints a character for spacing.
	li $v0, 11
	syscall

	# Create 2 buckets of length 8 on the heap. This is just to test the
	# function. Look at the "heap" section of memory to verify.
	li $a1, 2
	li $a2, 8
	jal create_buckets
	
	# Store pointers to the LUTs made by create_buckets.
	add $s0, $zero, $v0
	add $s1, $zero, $v1

	# Tests insert_into_bucket. Again, look at the heap to verify.
	addi $s2, $zero, 10		# Create a value we want to insert. (10 = 0b1010)
	add $a0, $zero, $s0		# A pointer to the update-intended LUT.
	addi $a1, $zero, 2		# The number of buckets we created.
	add $a2, $zero, $s2		# The value to insert.
	addi $a3, $zero, 0		# The digit to insert with respect to.
	jal insert_into_bucket

	# Store where the value was inserted.
	add $t0, $zero, $v0		# We don't care if this result is overwritten
							# since we never use it again.

	# Print out info about it.
	li $v0, 34
	add $a0, $zero, $s2
	syscall
	li $v0, 4
	la $a0, stored_at
	syscall
	li $v0, 34
	add $a0, $zero, $t0
	syscall

	

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
# Creates <n> buckets of <m> size. Stores two LUTs of their positions in
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
	# Create the first of the two LUTs.
	addi $v0, $zero, 9
	# Set the required size to enough bytes for a word-length pointer to
	# each bucket.
	mul $a0, $a1, 4
	# Perform the syscall that actually allocates the memory.
	syscall
	# Schindler's list the pointer into $t0 so we don't overwrite it.
	add $t0, $zero, $v0

	# Second LUT. Since $v0 was written to, we have to reload the value.
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
		
		# Add the address to the LUTs, and increment them.
		sw $v0, ($t0)
		sw $v1, ($t1)
		addi $t0, $t0, 4
		addi $t1, $t1, 4

		# Increment the counter.
		addi $t2, $t2, 1

	# On the next episode of Bucket Creation Loop, we do the same darn thing!
	# Oh did I say Bucket Creation Loop? I meant to say MGSV.
	j bucket_creation_loop

	return_create_buckets: # Fly out of the loop? You'll land here.
	# Now that the LUTs are created, we need to return the pointers to
	# the start. Oh, and since we don't need $a1 anymore, we can just use
	# it.
	mul $a1, $a1, 4
	sub $v0, $t0, $a1 # Put these things into the return registers.
	sub $v1, $t1, $a1
	
	# Return.
	jr $ra

#------------------------------------------------------------------------------
# Function: insert_into_bucket
# Takes a value, a particular digit to consider from it, a pointer to an
# LUT of bucket pointers, and how many buckets there are. With this data
# this function inserts the value into the correct bucket.
# Parameters:
#	a0: A pointer to the read-write bucket LUT.
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
	
	# Multiply the digit we just got by 4 to get an offset into the LUT.
	mul $t0, $t0, 4

	# Since we can't offset into the LUT by a register value, we need to prepare
	# the offset ourselves. This adds the value of the digit we extracted
	# to the starting address of the LUT.
	add $t0, $t0, $a0

	# Get the address of the bucket itself from the LUT.
	lw $t1, ($t0)

	# Store the value at that address.
	sw $a2, ($t1)

	# Put the address of where the value was stored into the result register.
	add $v0, $zero, $t1

	# Increment the pointer to the bucket so it points to its next slot.
	addi $t1, $t1, 4

	# Update the LUT with the new address.
	sw $t1, ($t0)

	# Finally we can get out of this function.
	jr $ra
	
	
	
	
