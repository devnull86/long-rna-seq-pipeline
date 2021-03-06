#!/bin/bash
# align-tophat-se.sh

script_name="align-tophat-se.sh"
script_ver="1.0.2"

main() {
    # Now in resources/usr/bin
    ## install tophat 2.0.8
    #wget http://ccb.jhu.edu/software/tophat/downloads/tophat-2.0.8.Linux_x86_64.tar.gz
    ## install bowtie2_2.1.0
    #wget http://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.1.0/bowtie2-2.1.0-linux-x86_64.zip/download
    #wget https://github.com/samtools/samtools/archive/0.1.19.tar.gz
    #wget wget https://github.com/xweigit/xweiEncodeScripts/archive/v1.0.tar.gz

    # If available, will print tool versions to stderr and json string to stdout
    versions=''
    if [ -f /usr/bin/tool_versions.py ]; then 
        versions=`tool_versions.py --applet $script_name --appver $script_ver`
    fi
    #echo "*****"
    #echo "* Running: align-tophat-se.sh [v1.0.1]"
    #echo "* TopHat version: "`tophat -v | awk '{print $2}'`
    #echo "* bowtie2 version: "`bowtie2 --version 2>&1 | grep bowtie | awk '{print $3}'`
    #echo "* samtools version: "`samtools 2>&1 | grep Version | awk '{print $2}'`
    #echo "* tophat_bam_xsA_tag_fix.pl version: "`perl /usr/bin/tophat_bam_xsA_tag_fix.pl --version 2>&1`
    #echo "*****"

    echo "* Value of reads: '$reads'"
    echo "* Value of tophat_index: '$tophat_index'"
    echo "* Value of library_id: '$library_id'"
    echo "* Value of nthreads: '$nthreads'"

    echo "* Download files..."
    reads_fn=`dx describe "$reads" --name`
    reads_fn=${reads_fn%.fastq.gz}
    reads_fn=${reads_fn%.fq.gz}
    dx download "$reads" -o "$reads_fn".fastq.gz
    echo "* Read file: '"$reads_fn".fastq.gz'"

    dx download "$tophat_index" -o tophat_index.tgz
    tar zxvf tophat_index.tgz

    # unzips into "out/"
    gff=`ls out/*.gff`
    anno_prefix=${gff%.gff}
    bamComments=`ls out/*_bamCommentLines.txt`
    geno_prefix=${bamComments%_bamCommentLines.txt}
    echo "* Value of geno_prefix: '$geno_prefix'"
    echo "* Value of anno_prefix: '$anno_prefix'"

    # Fill in your application code here.

    echo "* Map reads..."
    tophat -p ${nthreads} -z0 -a 8 -m 0 --min-intron-length 20 --max-intron-length 1000000 \
        --read-edit-dist 4 --read-mismatches 4 -g 20  --library-type fr-unstranded \
        --transcriptome-index ${anno_prefix} ${geno_prefix} ${reads_fn}.fastq.gz

    echo "* Set up headers..."
    HD="@HD\tVN:1.4\tSO:coordinate" 
    stCommand="perl tophat_bam_xsA_tag_fix.pl tophat_out/accepted_hits.bam | samtools view -bS - | samtools sort - mapped_fixed; samtools merge -h newHeader.sam merged.bam mapped_fixed.bam out/unmapped.bam"
    newPG="@PG\tID:Samtools\tPN:Samtools\tCL:"$stCommand"\tPP:Tophat\tVN:VN:0.1.17 (r973:277)"
    libraryComment="@CO\tLIBID:${library_id}"

    samtools view -H tophat_out/accepted_hits.bam | \
    gawk -v HD="$HD" -v newPG="$newPG" -v library="$libraryComment" \
        '{     if ($0 ~ /^@PG/) {PG=$0} 
          else if ($0 ~ /^@HD/) {print HD; }
          else if($0 ~ /^@SQ/) {print $0};
         }; END{print newPG"\n"PG"\n"library;}' > newHeader.sam

    # Add reference genome and transcriptome used
    cat ${geno_prefix}_bamCommentLines.txt >> newHeader.sam
    cat newHeader.sam

    echo "* Fix unmapped bam and sort before merge..."
    #perl /usr/bin/tophat_bam_xsA_tag_fix.pl tophat_out/accepted_hits.bam | \
    #            samtools view -bS - | samtools sort - mapped_fixed
    mv tophat_out/accepted_hits.bam mapped_fixed.bam

    echo "* Merge aligned and unaligned into single bam, using the patched up header..."
    samtools merge -h newHeader.sam merged.bam mapped_fixed.bam tophat_out/unmapped.bam
    # Note: no longer making unused index.
    #samtools index merged.bam

    mv merged.bam ${reads_fn}_tophat.bam
    #mv merged.bam.bai ${reads_fn}_tophat.bam.bai

    echo "* Upload results..."
    tophat_bam=$(dx upload ${reads_fn}_tophat.bam --property SW="$versions" --brief)
    dx-jobutil-add-output tophat_bam "$tophat_bam" --class=file
    echo "* Finished."
}
