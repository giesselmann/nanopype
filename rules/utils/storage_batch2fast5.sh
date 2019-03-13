# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : extract single fast5 from bulk or index file
#
#  DESCRIPTION   : none
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# ---------------------------------------------------------------------------------
# Copyright (c) 2018-2019, Pay Giesselmann, Max Planck Institute for Molecular Genetics
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Written by Pay Giesselmann
# ---------------------------------------------------------------------------------

# cmd line arguments
batch_file=$1
raw_dir=$2
target_dir=$3
pipeline_dir=$4
python_bin=$5


# batch type from file extension
batch_file_name=$(basename -- "$batch_file")
batch_file_ext="${batch_file_name##*.}"


# extract based on batch type
case $batch_file_ext in
	"tar")
		# batch of single read fast5 in .tar format
		tar -C $target_dir -xf $batch_file
	;;
	"fast5")
		# batch of single reads in bulk file
		$python_bin $pipeline_dir/submodules/ont_fast5_api/ont_fast5_api/conversion_tools/multi_to_single_fast5.py -i $batch_file -s $target_dir
	;;
	"txt")
		# batch of single read in file of IDs, requires indexed run
		# TODO
	;;
	*)
		echo "Unrecognized batch type."
		exit -1
	;;
esac

