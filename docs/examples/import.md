# Data Import

Raw data from the sequencer in *fast5* format needs to be imported into nanopype compatible batches. Each batch contains a configurable number of reads. This tutorial covers the import and indexing of multiple runs.

Since the provided test data is already properly packaged, we need to restore the original MinKNOW output.

```
mkdir -p data/import
for d in data/raw/*; do\
    run=$(basename $d);
    mkdir -p data/import/$run;
    echo $run;
    ls $d/reads/*.tar | xargs -n 1 tar -C data/import/$run -xf;
done
```

### Packaging
The next steps use the import script of nanopype to pack single reads into *tar* archives. First we reproduce the test data archives:

```
mkdir -p data/raw2
for d in data/import/*; do\
    run=$(basename $d);
    python3 ~/src/nanopype/scripts/nanopype_import.py data/raw2/$run $d \
     --recursive --batch_size 4;
done
```

An import session is generating detailed output similar to the following:

    19.12.2018 00:23:35 [INFO] Logger created
    19.12.2018 00:23:35 [INFO] Writing output to /home/devel/nanopype_test/data/raw2/20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64/reads
    19.12.2018 00:23:35 [INFO] Inspect existing files and archives
    19.12.2018 00:23:35 [INFO] 0 raw files already archived
    19.12.2018 00:23:35 [INFO] 12 raw files to be archived
    19.12.2018 00:23:35 [INFO] Archived 4 reads in /home/devel/nanopype_test/data/raw2/20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64/reads/0.tar
    19.12.2018 00:23:35 [INFO] Archived 4 reads in /home/devel/nanopype_test/data/raw2/20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64/reads/1.tar
    19.12.2018 00:23:35 [INFO] Archived 4 reads in /home/devel/nanopype_test/data/raw2/20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64/reads/2.tar
    19.12.2018 00:23:35 [INFO] Mission accomplished

### Verification

To compare the nanopype test archives to the newly created ones you could run:

```
run=20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64
cmp --silent data/raw2/$run/reads/0.tar data/raw/$run/reads/0.tar &&\
 echo 'Archives identical!'
```

Re-running the archive script will detect already existing data and create new batches if the source directory contains files not yet present in the output folder.

```
run=20180221_FAH48596_FLO-MIN107_SQK-LSK108_human_Hues64
python3 ~/src/nanopype/scripts/nanopype_import.py data/raw2/$run data/import/$run\
 --recursive --batch_size 4;
```

It is recommend to always run the verification after an import process to ensure all reads from the sequencer are successfully archived.
