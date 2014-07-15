#!/bin/bash
# bam-to-bigwig 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

main() {

    echo "Value of bam_file: '$bam_file'"
    echo "Value of bai_file: '$bai_file'"
    echo "Value of star_index: '$star_index'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    echo "Download files"
    bam_fn=`dx describe "$bam_file" --name | cut -d'.' -f1`
    dx download "$bam_file" -o $bam_fn.bam

    dx download "$bai_file" -o $bam_fn.bai

    dx download "$star_index" -o - | tar zxvf -
    ## Note we only need the chrNameLength.txt, not any STAR specific indices


    echo "install Georgi's bam->wiggle"
    git clone https://github.com/georgimarinov/GeorgiScripts
    (cd GeorgiScripts; git checkout e7a6ae12e65b7b8a391dc511b8d94b7173225bbb)
    ## note initial version
    pip install pysam
    #GeorgiScript dependency
    # Fill in your application code here.
    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.

    echo "make wiggle from all mapped reads"
    python GeorgiScripts/makewigglefromBAM-NH.py --- ${bam_fn}.bam out/chrNameLength.txt tmpAllUn.wig \
           -RPM -notitle -fragments second-read-strand
    /usr/bin/wigToBigWig tmpAllUn.wig stdin out/chrNameLength.txt \
    ${bam_fn}_tophat_signal_unstranded_All.bw

    echo "make wiggle from uniquely mapping reads"
    python GeorgiScripts/makewigglefromBAM-NH.py --- ${bam_fn}.bam out/chrNameLength.txt tmpUniqUn.wig \
          -nomulti -RPM -notitle -fragments second-read-strand
    perl -pe 's/-//g' < tmpUniqUn.wig | /usr/bin/wigToBigWig stdin out/chrNameLength.txt \
    ${bam_fn}_tophat_signal_unstranded_Unique.bw


    # The following line(s) use the dx command-line tool to upload your file
    # outputs after you have created them on the local file system.  It assumes
    # that you have used the output field name for the filename for each output,
    # but you can change that behavior to suit your needs.  Run "dx upload -h"
    # to see more options to set metadata.

    all_unstranded_bw=$(dx upload ${bam_fn}_tophat_signal_unstranded_All.bw --brief)
    unique_unstranded_bw=$(dx upload ${bam_fn}_tophat_signal_unstranded_Unique.bw--brief)

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output all_bw "$all_unstranded_bw" --class=file
    dx-jobutil-add-output unique_bw "$unique_unstranded_bw" --class=file
}
