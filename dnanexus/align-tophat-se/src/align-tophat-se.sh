#!/bin/bash
# align-tophat-se 0.0.1
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

    echo "Value of reads: '$reads'"
    echo "Value of tophat_index: '$tophat_index'"
    echo "Value of library_id: '$library_id'"
    echo "Value of nthreads: '$nthreads'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    git clone https://github.com/xweigit/xweiEncodeScripts/
    # warining no version lock!

    echo "Download files"
    reads_fn=`dx describe "$reads" --name | cut -d'.' -f1`
    dx download "$reads" -o "$reads_fn".fastq.gz
    #gunzip "$reads_fn".fastq.gz

    dx download "$tophat_index" -o tophat_index.tgz
    tar zxvf tophat_index.tgz

    # unzips into "out/"
    gff=`ls out/*.gff`
    index_prefix=${gff%.gff}
    echo "found $index_prefix gff file"

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
    echo "set up headers"

    echo "map reads"

    /usr/bin/tophat -p ${nthreads} -z0 -a 8 -m 0 --min-intron-length 20 --max-intron-length 1000000 \
       --read-edit-dist 4 --read-mismatches 4 -g 20  \
       --library-type fr-unstranded --transcriptome-index ${index_prefix} ${index_prefix} ${reads_fn}.fastq.gz


    /usr/bin/samtools view -H tophat_out/accepted_hits.bam > header.txt
    echo "@PG  ID:Bowtie   VN:2.1.0.0" >> header.txt
    echo "@PG ID:Samtools VN:0.1.17.0" >> header.txt
    echo "@CO ID:Gencode  VN:19" >> header.txt

    /usr/bin/samtools reheader header.txt tophat_out/accepted_hits.bam > tmp.bam
    mv tmp.bam tophat_out/accepted_hits.bam

    /usr/bin/samtools reheader header.txt tophat_out/unmapped.bam > tmp.bam
    mv tmp.bam tophat_out/unmapped.bam
    # sort before merge

    /usr/bin/samtools merge merged.bam tophat_out/accepted_hits.all.bam tophat_out/unmapped.bam

    mv merged.bam ${reads_fn}_tophat_genome.bam
    /usr/bin/samtools index merged.bam merged.bai
    mv merged.bai ${reads_fn}_tophat_genome.bai

    genome_bam=$(dx upload ${reads_fn}_tophat_genome.bam --brief)
    genome_bai=$(dx upload ${reads_fn}_tophat_genome.bai --brief)
     # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output genome_bam "$genome_bam" --class=file
    dx-jobutil-add-output genome_bai "$genome_bai" --class=file
}
